class Norm::Query
  def initialize(conn, table, options={})
    @conn, @table, @options = conn, table, options
  end

  attr_accessor :options

  # Restricts the query to a given number of results.
  def limit(n)
    @options[:limit] = n
    self
  end

  # Constructs the SQL for this query.
  def sql
    "SELECT * FROM #{Norm.quote_table(@table)}"
  end

  # Executes the constructed query and returns an Array of Hashes of results.
  def execute!
    @conn.exec(sql) do |pg_result|
      Norm.format_results(pg_result, pg_result)
    end
  end
end

# vim: set sw=2 cc=80 et:
