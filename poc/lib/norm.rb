require 'pg'

module Norm
  def self.connect!
    @conn = PG.connect(:dbname => 'nao_testing')
  end

  def self.execute(sql, &block)
    @conn.exec(sql, &block)
  end

  def self.quote_table(name)
    PG::Connection.quote_ident(name)
  end

  class Query
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

  # Returns a new Norm::Query object for +table+.
  def self.query(table)
    @queries ||= {}
    @queries[table] ||= Query.new(@conn, table.to_s)
  end

  # Formats the Hash +result+ according to the column types identifiable from
  # the PG::Result +pg_result+.
  # TODO: memoization.
  def self.format_result(result, pg_result)
    # See: http://deveiate.org/code/pg/PG/Result.html#method-i-ftype
    col_types = {}
    pg_result.nfields.times do |n|
      @conn.exec("SELECT format_type($1, $2)", [pg_result.ftype(n), pg_result.fmod(n)]) do |res|
        col_types[pg_result.fname(n)] = res.getvalue(0, 0)
      end
    end

    normalize_result(result, col_types)
  end

  # Normalizes the Hash +result+ (of Strings to Strings), with +col_types+
  # specifying String column names to String PostgreSQL types.
  def self.normalize_result(result, col_types)
    Hash[result.map {|k,v|
      [k.to_sym, convert_type(v, col_types[k])]
    }]
  end

  # Converts +value+ to a native Ruby value, based on the PostgreSQL type
  # +type+.
  def self.convert_type(value, type)
    case type
    when "integer"
      value.to_i
    else
      value
    end
  end
end

