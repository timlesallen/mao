class Norm::Query
  def initialize(conn, table)
    @conn, @table = conn, table
  end

  def first
    @conn.exec("SELECT * FROM #{Norm.quote_table(@table)} LIMIT 1") do |pg_result|
      next if pg_result.num_tuples.zero?
      Norm.format_result(pg_result[0], pg_result)
    end
  end
end

