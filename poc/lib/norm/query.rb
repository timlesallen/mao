class Norm::Query
  def initialize(conn, table)
    @conn, @table = conn, table
  end

  def execute!
    @conn.exec("SELECT * FROM #{Norm.quote_table(@table)}") do |pg_result|
      Norm.format_results(pg_result, pg_result)
    end
  end
end

