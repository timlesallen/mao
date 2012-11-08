# A persistent query structure which can be manipulated by creating new
# persistent queries, and eventually executed.
#
# All "state" about the query itself is deliberately stored in a simple Hash,
# @options, to provide transparency and ensure simplicity of the resulting
# design.
class Norm::Query
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

  # Restricts the query to a given number of results.
  def limit(n)
    with_options(:limit => n)
  end

  # Constructs the SQL for this query.
  def sql
    s = "SELECT * FROM #{Norm.quote_table(@table)}"
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
