require 'pg'

module Norm
  require 'norm/query'

  # Connect to the database.
  def self.connect!
    @conn = PG.connect(:dbname => 'nao_testing')
  end

  # Execute the raw SQL +sql+.  The returned object varies depending on the
  # database vendor.
  def self.sql(sql, &block)
    @conn.exec(sql, &block)
  end

  # Quote +name+ as appropriate for a table name in an SQL statement.
  def self.quote_table(name)
    PG::Connection.quote_ident(name)
  end

  # Returns a new Norm::Query object for +table+.
  def self.query(table)
    @queries ||= {}
    @queries[table] ||= Query.new(@conn, table.to_s)
  end

  # Formats the Array of Hashes +results+ according to the column types
  # identifiable from the PG::Result +pg_result+.
  # TODO: memoization.
  def self.format_results(results, pg_result)
    # See: http://deveiate.org/code/pg/PG/Result.html#method-i-ftype
    col_types = {}
    pg_result.nfields.times do |n|
      @conn.exec("SELECT format_type($1, $2)",
                 [pg_result.ftype(n), pg_result.fmod(n)]) do |res|
        col_types[pg_result.fname(n)] = res.getvalue(0, 0)
      end
    end

    results.map {|result| normalize_result(result, col_types)}
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

# vim: set sw=2 cc=80 et:
