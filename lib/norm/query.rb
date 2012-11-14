# A persistent query structure which can be manipulated by creating new
# persistent queries, and eventually executed.
#
# All "state" about the query itself is deliberately stored in a simple Hash,
# @options, to provide transparency and ensure simplicity of the resulting
# design.
class Norm::Query
  require 'norm/filter'

  # A container for text that should be inserted raw into a query.
  class Raw
    def initialize(text)
      @text = text
    end

    attr_reader :text
  end

  # Returns a Norm::Query::Raw with +text+.
  def self.raw(text)
    Raw.new(text).freeze
  end

  def initialize(table, options={}, col_types=nil)
    @table, @options = table.freeze, options.freeze

    if !col_types
      col_types = {}
      Norm.sql(
          'SELECT column_name, data_type FROM information_schema.columns ' \
          'WHERE table_name=$1',
          [@table]) do |pg_result|
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

  attr_reader :table
  attr_reader :options
  attr_reader :col_types

  # Returns a new Norm::Query with +options+ merged into the options of this
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

  # Only returns the given +columns+.
  def only(*columns)
    columns = columns.flatten

    columns.each do |column|
      unless column.is_a? Symbol
        raise ArgumentError, "#{column.inspect} not a String"
      end
      unless @col_types[column]
        raise ArgumentError, "#{column.inspect} is not a column in this table"
      end
    end

    with_options(:only => columns)
  end

  # For INSERTs, returns +columns+ for inserted rows.
  def returning(*columns)
    columns = columns.flatten

    columns.each do |column|
      unless column.is_a? Symbol
        raise ArgumentError, "#{column.inspect} not a String"
      end
      unless @col_types[column]
        raise ArgumentError, "#{column.inspect} is not a column in this table"
      end
    end

    with_options(:returning => columns)
  end

  # Filters results based on the conditions specified in +block+.
  #
  # +block+ has available in context the column names of the table being
  # queried; use regular operators to construct tests, e.g. "x == 3" will
  # filter where the column "x" has value 3.
  #
  # Boolean operations on columns return Norm::Filter objects; use #and and #or
  # to combine them.  The return value of the block should be the full desired
  # filter.
  def where(&block)
    context = Norm::Filter::Table.new(self, false).freeze

    with_options(:where => context.instance_exec(&block).finalize)
  end

  # A context for the #join DSL.  Any non-lexically bound names hit
  # JoinContext#method_missing, which constructs a Norm::Filter::Table for the
  # table with that name.
  class JoinContext
    # Ensure +args+ and +block+ are both empty.  Creates a Norm::Query for the
    # name invoked, which ensures such a table exists.  Assuming it exists, a
    # Norm::Filter::Table for that query is constructed.
    def method_missing(name, *args, &block)
      if args.length > 0
        raise ArgumentError, "args not expected in #where subclause"
      end

      if block
        raise ArgumentError, "block not expected in #where subclause"
      end

      Norm::Filter::Table.new(Norm.query(name), true).freeze
    end
  end

  def join(target, &block)
    context = JoinContext.new

    with_options(:join => [target, context.instance_exec(&block).finalize])
  end

  # Constructs the SQL for this query.
  def sql
    s = ""
    options = @options.dup

    if update = options.delete(:update)
      s = "UPDATE "
      s << Norm.quote_ident(@table)
      s << " SET "

      if update.length == 0
        raise ArgumentError, "invalid update: nothing to set"
      end

      s << update.map do |k,v|
        k = k.to_sym
        unless @col_types[k]
          raise ArgumentError, "no such column to update: #{k}"
        end

        "#{Norm.quote_ident(k.to_s)} = #{Norm.escape_literal(v)}"
      end.join(", ")

      if where = options.delete(:where)
        s << " WHERE "
        s << Norm::Filter.sql(where)
      end
    elsif insert = options.delete(:insert)
      s = "INSERT INTO "
      s << Norm.quote_ident(@table)
      s << " ("

      keys = insert.map(&:keys).flatten.uniq.sort
      s << keys.map do |k|
        k = k.to_sym
        unless @col_types[k]
          raise ArgumentError, "no such column to update: #{k}"
        end

        Norm.quote_ident(k.to_s)
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
            Norm.escape_literal(row[k])
          else
            "DEFAULT"
          end
        }.join(", ")
        s << ")"
      end

      if returning = options.delete(:returning)
        s << " RETURNING "
        s << returning.map {|c| Norm.quote_ident(c)}.join(", ")
      end
    else
      s = "SELECT "

      join = options.delete(:join)

      if only = options.delete(:only)
        s << only.map {|c| Norm.quote_ident(c)}.join(", ")
      elsif join
        # XXX OMG
        s << (@col_types.keys.sort.map {|c|
          "#{Norm.quote_ident(@table)}.#{Norm.quote_ident(c)} " +
          "#{Norm.quote_ident("#{@table}.#{c}")}"
        } + Norm.query(join[0]).col_types.keys.sort.map {|c|
          "#{Norm.quote_ident(join[0])}.#{Norm.quote_ident(c)} " +
          "#{Norm.quote_ident("#{join[0]}.#{c}")}"
        }).join(", ")
      else
        s << "*"
      end

      s << " FROM #{Norm.quote_ident(@table)}"

      if join
        s << " INNER JOIN #{Norm.quote_ident(join[0])} ON "
        s << Norm::Filter.sql(join[1])
      end

      if where = options.delete(:where)
        s << " WHERE "
        s << Norm::Filter.sql(where)
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
    Norm.sql(with_options(:update => nil).sql) do |pg_result|
      pg_result.map {|result| Norm.normalize_result(result, @col_types)}
    end
  end

  # Limits the query to one result, and returns that result.
  def select_first!
    limit(1).select!.first
  end

  # Executes the changes in Hash +changes+ to the rows matching this object,
  # returning the number of affected rows.
  def update!(changes)
    Norm.sql(with_options(:update => changes).sql) do |pg_result|
      pg_result.cmd_tuples
    end
  end

  # Inserts +rows+ into the table.  No other options should be applied to this
  # query.  Returns the number of inserted rows, unless #returning was called,
  # in which case the calculated values from the INSERT are returned.
  def insert!(*rows)
    Norm.sql(with_options(:insert => rows.flatten).sql) do |pg_result|
      if @options[:returning]
        pg_result.map {|result| Norm.normalize_result(result, @col_types)}
      else
        pg_result.cmd_tuples
      end
    end
  end
end

# vim: set sw=2 cc=80 et:
