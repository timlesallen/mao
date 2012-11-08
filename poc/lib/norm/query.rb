class Norm::Query
  def initialize(conn, table)
    @conn, @table = conn, table
  end

  # Executes the constructed query and returns an Array of Hashes of results.
  def execute!
    @conn.exec("SELECT * FROM #{Norm.quote_table(@table)}") do |pg_result|
      Norm.format_results(pg_result, pg_result)
    end
  end
end

# vim: set sw=2 et:
