# A persistent query structure which can be manipulated by creating new
# persistent queries, and eventually executed.
#
# All "state" about the query itself is deliberately stored in a simple Hash,
# @options, to provide transparency and ensure simplicity of the resulting
# design.
class Mao::Query
  require 'mao/filter'

  # A container for text that should be inserted raw into a query.
  class Raw
    # Creates the Mao::Query::Raw with SQL +text+.
    def initialize(text)
      @text = text
    end

    # The raw SQL text.
    attr_reader :text
  end

  # Returns a Mao::Query::Raw with +text+.
  def self.raw(text)
    Raw.new(text).freeze
  end

  # Constructs the Query with reference to a table named +table+, and immutable
  # options hash +options+.  +col_types+ is column information for the table,
  # usually populated by a prior invocation of Mao::Query.new.
  def initialize(table, options={}, col_types=nil)
    @table, @options = table.to_sym, options.freeze

    if !col_types
      col_types = {}
      Mao.sql(
          'SELECT column_name, data_type FROM information_schema.columns ' \
          'WHERE table_name=$1',
          [@table.to_s]) do |pg_result|
        if pg_result.num_tuples.zero?
          raise ArgumentError, "invalid or blank table #@table"
        end

        pg_result.each do |tuple|
          col_types[tuple["column_name"].to_sym] = tuple["data_type"]
        end
      end
    end

    @col_types = col_types.freeze
  end

  # A symbol of the name of the table this Query points to.
  attr_reader :table

  # The immutable options hash of this Query instance.
  attr_reader :options

  # The cached information about columns and their types for the table being
  # referred to.
  attr_reader :col_types

  # Returns a new Mao::Query with +options+ merged into the options of this
  # object.
  def with_options(options)
    self.class.new(@table, @options.merge(options), @col_types).freeze
  end

  # Restricts the query to at most +n+ results.
  def limit(n)
    unless n.is_a? Integer
      raise ArgumentError, "#{n.inspect} not an Integer"
    end

    with_options(:limit => n.to_i)
  end

  # Returns the query's results sorted by +column+ in +direction+, either :asc
  # or :desc.
  def order(column, direction)
    unless column.is_a?(Symbol) and [:asc, :desc].include?(direction)
      raise ArgumentError,
        "#{column.inspect} not a Symbol or " \
        "#{direction.inspect} not :asc or :desc"
    end

    check_column(column, @table, @col_types)

    direction = direction == :asc ? "ASC" : "DESC"
    with_options(:order => [column, direction])
  end

  # Only returns the given +columns+, Symbols (possibly nested in Arrays).
  #
  # If +columns+ is a single argument, and it's a Hash, the keys should be
  # Symbols corresponding to table names, and the values Arrays of Symbol
  # column names.  This is only for use with #join, and #only must be called
  # after #join.
  def only(*columns)
    columns = columns.flatten

    if columns.length == 1 and columns[0].is_a?(Hash)
      unless @options[:join]
        raise ArgumentError, "#only with a Hash must be used only after #join"
      end

      other = Mao.query(@options[:join][0])
      columns = columns[0]
      columns.each do |table, table_columns|
        unless table_columns.is_a? Array
          raise ArgumentError, "#{table_columns.inspect} is not an Array"
        end

        if table == @table
          table_columns.each do |column|
            check_column(column, @table, @col_types)
          end
        elsif table == other.table
          table_columns.each do |column|
            check_column(column, other.table, other.col_types)
          end
        else
          raise ArgumentError, "#{table} is not a column in this query"
        end
      end
    else
      columns.each do |column|
        check_column(column, @table, @col_types)
      end
    end

    with_options(:only => columns)
  end

  # For INSERTs, returns +columns+ for inserted rows.
  def returning(*columns)
    columns = columns.flatten

    columns.each do |column|
      check_column(column, @table, @col_types)
    end

    with_options(:returning => columns)
  end

  # A context for the #join DSL.  Any non-lexically bound names hit
  # JoinContext#method_missing, which constructs a Mao::Filter::Table for the
  # table with that name.
  class JoinContext
    # Ensure +args+ and +block+ are both empty.  Creates a Mao::Query for the
    # name invoked, which ensures such a table exists.  Assuming it exists, a
    # Mao::Filter::Table for that query is constructed.
    def method_missing(name, *args, &block)
      if args.length > 0
        raise ArgumentError, "args not expected in #where subclause"
      end

      if block
        raise ArgumentError, "block not expected in #where subclause"
      end

      Mao::Filter::Table.new(Mao.query(name), true).freeze
    end
  end

  # Filters results based on the conditions specified in +block+.
  #
  # Depending on if #join has been called, one of two things occur:
  #   1. If #join has not been called, +block+ has available in context the
  #      column names of the table being queried; or,
  #   2. If #join has been called, +block+ has available in context the table
  #      names of the tables involved in the query.  Per #join, those objects
  #      will have the columns available as methods.
  #
  # Once you have a column, use regular operators to construct tests, e.g. "x
  # == 3" will filter where the column "x" has value 3.
  #
  # Boolean operations on columns return Mao::Filter objects; use #and and #or
  # to combine them.  The return value of the block should be the full desired
  # filter.
  def where(&block)
    if @options[:join]
      context = JoinContext.new.freeze
    else
      context = Mao::Filter::Table.new(self, false).freeze
    end

    with_options(:where => context.instance_exec(&block).finalize)
  end

  # Joins the results of this table against another table, +target+.  The
  # conditions for joining one row in this table against one in +target+ are
  # specified in +block+.
  #
  # +block+ is per #where's, except the names in context are tables, not
  # columns; the tables returned are the same as the context of #where itself,
  # so for instance, "blah.x == 3" will filter where the column "x" of table
  # "blah" (which should be either this table, or the +target+ table) equals 3.
  #
  # Boolean operations are then all per #where.
  #
  # If +block+ is not specified, +target+ is instead treated as a Hash of the
  # form {foreign_table => {local_key => foreign_key}}.
  def join(target, &block)
    if !block
      local_table = @table
      foreign_table = target.keys[0]
      mapping = target[foreign_table]
      local_key = mapping.keys[0]
      foreign_key = mapping[local_key]
      return join(foreign_table) {
        send(local_table).send(local_key) ==
          send(foreign_table).send(foreign_key)
      }
    end

    context = JoinContext.new.freeze

    with_options(:join => [target, context.instance_exec(&block).finalize])
  end

  # Constructs the SQL for this query.
  def sql
    s = ""
    options = @options.dup

    if update = options.delete(:update)
      s = "UPDATE "
      s << Mao.quote_ident(@table)
      s << " SET "

      if update.length == 0
        raise ArgumentError, "invalid update: nothing to set"
      end

      s << update.map do |column, value|
        check_column(column, @table, @col_types)

        "#{Mao.quote_ident(column)} = #{Mao.escape_literal(value)}"
      end.join(", ")

      if where = options.delete(:where)
        s << " WHERE "
        s << Mao::Filter.sql(where)
      end
    elsif insert = options.delete(:insert)
      s = "INSERT INTO "
      s << Mao.quote_ident(@table)
      s << " ("

      keys = insert.map(&:keys).flatten.uniq.sort
      s << keys.map do |column|
        check_column(column, @table, @col_types)
        Mao.quote_ident(column)
      end.join(", ")
      s << ") VALUES "

      first = true
      insert.each do |row|
        if first
          first = false
        else
          s << ", "
        end

        s << "("
        s << keys.map {|k|
          if row.include?(k)
            Mao.escape_literal(row[k])
          else
            "DEFAULT"
          end
        }.join(", ")
        s << ")"
      end

      if returning = options.delete(:returning)
        s << " RETURNING "
        s << returning.map {|c| Mao.quote_ident(c)}.join(", ")
      end
    else
      s = "SELECT "

      join = options.delete(:join)
      only = options.delete(:only)

      if join
        n = 0
        s << (@col_types.keys.sort.map {|c|
          n += 1
          if !only or (only[@table] and only[@table].include?(c))
            "#{Mao.quote_ident(@table)}.#{Mao.quote_ident(c)} " +
            "#{Mao.quote_ident("c#{n}")}"
          end
        } + Mao.query(join[0]).col_types.keys.sort.map {|c|
          n += 1
          if !only or (only[join[0]] and only[join[0]].include?(c))
            "#{Mao.quote_ident(join[0])}.#{Mao.quote_ident(c)} " +
            "#{Mao.quote_ident("c#{n}")}"
          end
        }).reject(&:nil?).join(", ")
      elsif only
        s << only.map {|c| Mao.quote_ident(c)}.join(", ")
      else
        s << "*"
      end

      s << " FROM #{Mao.quote_ident(@table)}"

      if join
        s << " INNER JOIN #{Mao.quote_ident(join[0])} ON "
        s << Mao::Filter.sql(join[1])
      end

      if where = options.delete(:where)
        s << " WHERE "
        s << Mao::Filter.sql(where)
      end

      if order = options.delete(:order)
        s << " ORDER BY "
        s << Mao.quote_ident(order[0])
        s << " "
        s << order[1]
      end

      if limit = options.delete(:limit)
        s << " LIMIT #{limit}"
      end
    end

    if options.length > 0
      raise ArgumentError,
          "invalid options in #sql: #{options.inspect}. " \
          "SQL constructed: #{s}"
    end

    s
  end

  # Executes the constructed query and returns an Array of Hashes of results.
  def select!
    # Ensure we can never be destructive by nilifying :update.
    Mao.sql(with_options(:update => nil).sql) do |pg_result|
      if @options[:join]
        other = Mao.query(@options[:join][0])
        pg_result.map {|result|
          Mao.normalize_join_result(result, self, other)
        }
      else
        pg_result.map {|result| Mao.normalize_result(result, @col_types)}
      end
    end
  end

  # Limits the query to one result, and returns that result.
  def select_first!
    limit(1).select!.first
  end

  # Executes the changes in Hash +changes+ to the rows matching this object,
  # returning the number of affected rows.
  def update!(changes)
    Mao.sql(with_options(:update => changes).sql) do |pg_result|
      pg_result.cmd_tuples
    end
  end

  # Inserts +rows+ into the table.  No other options should be applied to this
  # query.  Returns the number of inserted rows, unless #returning was called,
  # in which case the calculated values from the INSERT are returned.
  def insert!(*rows)
    Mao.sql(with_options(:insert => rows.flatten).sql) do |pg_result|
      if @options[:returning]
        pg_result.map {|result| Mao.normalize_result(result, @col_types)}
      else
        pg_result.cmd_tuples
      end
    end
  end

  private

  # Checks that +column+ is a valid column reference in +table+, given
  # +col_types+ for the table.
  def check_column column, table, col_types
    unless column.is_a? Symbol
      raise ArgumentError, "#{column.inspect} not a Symbol"
    end
    unless col_types[column]
      raise ArgumentError, "#{column.inspect} is not a column in #{table}"
    end
  end
end

# vim: set sw=2 cc=80 et:
