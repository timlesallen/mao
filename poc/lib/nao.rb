require 'pg'

module Nao
  def self.connect!
    @conn = PG.connect(:dbname => 'nao_testing')
  end

  class Query
    def initialize(conn, table)
      @conn, @table = conn, table
    end

    def first
      @conn.exec("SELECT * FROM #{PG::Connection.quote_ident(@table)} LIMIT 1") do |pg_result|
        next if pg_result.num_tuples.zero?
        Nao.format_result(pg_result[0], pg_result)
      end
    end
  end

  def self.query(table)
    @queries ||= {}
    @queries[table] ||= Query.new(@conn, table.to_s)
  end

  def self.symbolize_keys(hash)
    Hash[hash.map {|k,v| [k.to_sym, v]}]
  end

  def self.format_result(hash, pg_result)
    # Possibly lookup column types of the table (cache it too?), convert.
    # See: http://deveiate.org/code/pg/PG/Result.html#method-i-ftype
    Nao.symbolize_keys(pg_result[0])
  end
end

