# A persistent query structure which can be manipulated by creating new
# persistent queries, and eventually executed.
#
# All "state" about the query itself is deliberately stored in a simple Hash,
# @options, to provide transparency and ensure simplicity of the resulting
# design.
class Norm::Query
  require 'norm/filter'

  def initialize(conn, table, options={})
    @conn, @table, @options = conn, table.freeze, options.freeze
  end

  attr_reader :conn
  attr_reader :table
  attr_reader :options

  # Returns a new Norm::Query with +options+ merged into the options of this
  # object.
  def with_options(options)
    self.class.new(@conn, @table, @options.merge(options)).freeze
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
      unless column.is_a? String
        raise ArgumentError, "#{column.inspect} not a String"
      end
    end

    with_options(:only => columns)
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
    context = Object.new

    def context.method_missing(name, *args, &block)
      if args.length > 0
        raise ArgumentError, "args not expected in #where subclause"
      end

      if block
        raise ArgumentError, "block not expected in #where subclause"
      end

      Norm::Filter::Column.new(:name => name).freeze
    end

    with_options(:where => context.instance_exec(&block))
  end

  # Constructs the SQL for this query.
  def sql
    s = "SELECT "

    if @options[:only]
      s << @options[:only].map {|c| Norm.quote_ident(c)}.join(", ")
    else
      s << "*"
    end

    s << " FROM #{Norm.quote_ident(@table)}"

    if @options[:where]
      s << " WHERE "
      s << @options[:where].sql
    end

    s << " LIMIT #{@options[:limit]}" if @options[:limit]
    s
  end

  # Executes the constructed query and returns an Array of Hashes of results.
  def execute!
    @conn.exec(sql) do |pg_result|
      Norm.format_results(pg_result, pg_result)
    end
  end
end

# vim: set sw=2 cc=80 et:
