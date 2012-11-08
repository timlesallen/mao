require 'pg'

# The top-level module to access Norm.
module Norm
  require 'norm/query'

  # Connect to the database.
  def self.connect!
    @conn ||= PG.connect(:dbname => 'norm_testing')
  end

  # Disconnect from the database.
  def self.disconnect!
    @conn.close
    @conn = nil
  end

  # Execute the raw SQL +sql+.  The returned object varies depending on the
  # database vendor.
  def self.sql(sql, &block)
    @conn.exec(sql, &block)
  end

  # Quote +name+ as appropriate for a table or column name in an SQL statement.
  def self.quote_ident(name)
    @conn.quote_ident(name)
  end

  # Escape +value+ as appropriate for a literal in an SQL statement.
  def self.escape_literal(value)
    case value
    when String
      @conn.escape_literal(value)
    when NilClass
      "null"
    when TrueClass
      "true"
    when FalseClass
      "false"
    when Numeric
      value.to_s
    else
      raise ArgumentError, "don't know how to escape #{value.class}"
    end
  end

  # Returns a new Norm::Query object for +table+.
  def self.query(table)
    @queries ||= {}
    @queries[table] ||= Query.new(@conn, table.to_s).freeze
  end

  # Normalizes the Hash +result+ (of Strings to Strings), with +col_types+
  # specifying Symbol column names to String PostgreSQL types.
  def self.normalize_result(result, col_types)
    Hash[result.map {|k,v|
      k = k.to_sym
      [k, convert_type(v, col_types[k])]
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
