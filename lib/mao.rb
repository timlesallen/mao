require 'pg'
require 'bigdecimal'

# The top-level module to access Mao.
module Mao
  require 'mao/query'

  # Connect to the database.  +options+ is currently the straight Postgres gem
  # options.
  def self.connect!(options)
    unless @conn
      @conn = PG.connect(options)
      @conn.internal_encoding = Encoding::UTF_8
    end
  end

  # Disconnect from the database.
  def self.disconnect!
    @conn.close
    @conn = nil
  end

  # Execute the raw SQL +sql+ with positional +args+.  The returned object
  # varies depending on the database vendor.
  def self.sql(sql, *args, &block)
    STDERR.puts "#{sql}#{args ? " " + args.inspect : ""}"
    @conn.exec(sql, *args, &block)
  end

  # Quote +name+ as appropriate for a table or column name in an SQL statement.
  def self.quote_ident(name)
    case name
    when Symbol
      @conn.quote_ident(name.to_s)
    else
      @conn.quote_ident(name)
    end
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
    when Array
      if value == []
        # NULL IN NULL is NULL in SQL, so this is "safe".  Empty lists () are
        # apparently part of the standard, but not widely supported (!).
        "(null)"
      else
        "(#{value.map {|v| escape_literal(v)}.join(", ")})"
      end
    when Mao::Query::Raw
      value.text
    when Time
      escape_literal(value.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    else
      raise ArgumentError, "don't know how to escape #{value.class}"
    end
  end

  # Returns a new Mao::Query object for +table+.
  def self.query(table)
    @queries ||= {}
    @queries[table] ||= Query.new(table).freeze
  end

  # When raised in a transaction, causes a rollback without the exception
  # bubbling.
  Rollback = Class.new(Exception)

  # Executes +block+ in a transaction.
  #
  # If +block+ executes without an exception, the transaction is committed.
  #
  # If a Mao::Rollback is raised, the transaction is rolled back, and
  # #transaction returns false.
  #
  # If any other Exception is raised, the transaction is rolled back, and the
  # exception is re-raised.
  #
  # Otherwise, the transaction is committed, and the result of +block+ is
  # returned.
  def self.transaction(&block)
    return block.call if @in_transaction
    @in_transaction = true

    sql("BEGIN")
    begin
      r = block.call
    rescue Rollback
      sql("ROLLBACK")
      return false
    rescue Exception
      sql("ROLLBACK")
      raise
    ensure
      @in_transaction = false
    end
    sql("COMMIT")
    r
  end

  # Normalizes the Hash +result+ (of Strings to Strings), with +col_types+
  # specifying Symbol column names to String PostgreSQL types.
  def self.normalize_result(result, col_types)
    Hash[result.map {|k,v|
      k = k.to_sym
      [k, convert_type(v, col_types[k])]
    }]
  end

  # Normalizes the Hash +result+ (of Strings to Strings), with the joining
  # tables of +from_query+ and +to_query+.  Assumes the naming convention for
  # result keys of Mao::Query#join (see Mao::Query#sql) has been followed.
  def self.normalize_join_result(result, from_query, to_query)
    results = {}
    n = 0

    from_table = from_query.table
    from_types = from_query.col_types
    from_types.keys.sort.each do |k|
      n += 1
      key = "c#{n}"
      if result.include?(key)
        results[from_table] ||= {}
        results[from_table][k] = convert_type(result[key], from_types[k])
      end
    end

    to_table = to_query.table
    to_types = to_query.col_types
    to_types.keys.sort.each do |k|
      n += 1
      key = "c#{n}"
      if result.include?(key)
        results[to_table] ||= {}
        results[to_table][k] = convert_type(result[key], to_types[k])
      end
    end

    results
  end

  # Converts +value+ to a native Ruby value, based on the PostgreSQL type
  # +type+.
  def self.convert_type(value, type)
    return nil if value.nil?

    case type
    when "integer", "smallint", "bigint", "serial", "bigserial"
      value.to_i
    when /^character varying/, "text"
      value
    when "timestamp without time zone"
      # We assume it's in UTC.  (Dangerous?)
      value =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)$/
      Time.new($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_f, 0)
    when "boolean"
      value == "t"
    when "bytea"
      PG::Connection.unescape_bytea(value)
    when "numeric"
      BigDecimal.new(value)
    else
      STDERR.puts "#{self.name}: unknown type: #{type}"
      value
    end
  end
end

# vim: set sw=2 cc=80 et:
