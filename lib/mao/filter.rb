# encoding: utf-8

# A mix-in for any kind of filter in a where clause (vis-à-vis
# Mao::Query#where).
module Mao::Filter
  # If +obj+ is a Mao::Filter, call #finalize on it; otherwise, use
  # Mao.escape_literal to escape +obj.to_s+.
  def self.finalize_or_literal(obj)
    if obj.is_a? Mao::Filter
      obj.finalize
    else
      Mao.escape_literal(obj)
    end
  end

  # Generate the SQL for the finalized object +finalized+.  If +finalized+ is a
  # String, it's returned without modification.
  def self.sql(finalized)
    if finalized.is_a? String
      finalized
    else
      klass, *args = finalized
      Mao::Filter.const_get(klass).sql(*args)
    end
  end

  # Initialize a filter object with the given options.  Filters are intended to
  # be used immutably, and all methods on same return new, immutable filters.
  def initialize(options={})
    @options = options.freeze
  end

  # The options hash for this filter.
  attr_reader :options

  # Returns an AND filter where the current object is the LHS and +rhs+ is the
  # RHS.
  def and(rhs)
    Mao::Filter::Binary.new(:op => 'AND', :lhs => self, :rhs => rhs).freeze
  end

  # Returns an OR filter where the current object is the LHS and +rhs+ is the
  # RHS.
  def or(rhs)
    Mao::Filter::Binary.new(:op => 'OR', :lhs => self, :rhs => rhs).freeze
  end

  # Returns an equality binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def ==(rhs)
    Mao::Filter::Binary.new(:op => '=', :lhs => self, :rhs => rhs)
  end

  # Returns an inequality binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def !=(rhs)
    Mao::Filter::Binary.new(:op => '<>', :lhs => self, :rhs => rhs)
  end

  # Returns a greater-than binary filter where the current object is the LHS
  # and +rhs+ is the RHS.
  def >(rhs)
    Mao::Filter::Binary.new(:op => '>', :lhs => self, :rhs => rhs)
  end

  # Returns a greater-than-or-equal-to binary filter where the current object
  # is the LHS and +rhs+ is the RHS.
  def >=(rhs)
    Mao::Filter::Binary.new(:op => '>=', :lhs => self, :rhs => rhs)
  end

  # Returns a less-than binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def <(rhs)
    Mao::Filter::Binary.new(:op => '<', :lhs => self, :rhs => rhs)
  end

  # Returns a less-than-or-equal-to binary filter where the current object is
  # the LHS and +rhs+ is the RHS.
  def <=(rhs)
    Mao::Filter::Binary.new(:op => '<=', :lhs => self, :rhs => rhs)
  end

  # Returns a filter where the current object is checked if it IS NULL.
  #   HACK(arlen): ? Calling this "nil?" results in the world crashing down
  #   around us.  But it seems a pity to have this be not-quite-like-Ruby.
  #   Would it be better to make #==(nil) map to IS NULL instead of = NULL?
  def null?
    Mao::Filter::Binary.new(:op => 'IS', :lhs => self, :rhs => nil)
  end

  # Returns a filter where the current object is checked if it is IN +rhs+,
  # typically a list.
  def in(rhs)
    Mao::Filter::Binary.new(:op => 'IN', :lhs => self, :rhs => rhs)
  end

  # A reference to a column('s value) in a filter.
  class Column
    include Mao::Filter

    # Produces an array which becomes part of the resulting Mao::Query's
    # options, used by Mao::Query#sql.
    def finalize
      if @options[:table]
        [:Column, @options[:table], @options[:name]]
      else
        [:Column, @options[:name]]
      end
    end

    # Used by Mao::Filter.sql to generate the actual SQL for a column
    # reference.
    def self.sql(*opts)
      opts.map {|i| Mao.quote_ident(i.to_s)}.join(".")
    end
  end

  # A binary operation on two filters.
  class Binary
    include Mao::Filter

    # Produces an array which becomes part of the resulting Mao::Query's
    # options, used by Mao::Query#sql.
    def finalize
      [:Binary,
       @options[:op],
       Mao::Filter.finalize_or_literal(@options[:lhs]),
       Mao::Filter.finalize_or_literal(@options[:rhs])]
    end

    # Used by Mao::Filter.sql to generate the actual SQL for a column
    # reference.
    def self.sql(op, lhs, rhs)
      s = "("
      s << Mao::Filter.sql(lhs)
      s << " "
      s << op
      s << " "
      s << Mao::Filter.sql(rhs)
      s << ")"
      s
    end
  end

  # A context for the Mao::Query#where DSL, and for Mao::Query#join's table
  # objects.  Any non-lexically bound names hit WhereContext#method_missing,
  # which checks if it belongs to a column, and if so, constructs a
  # Mao::Filter::Column.
  class Table
    # Constructs a Table; +query+ is the Mao::Query instance, and +explicit+
    # refers to whether we need to explicitly name tables in the generated SQL.
    # (e.g. when a JOIN is being performed)
    def initialize(query, explicit)
      @query = query
      @explicit = explicit
    end

    # Ensure +args+ and +block+ are both empty.  Assert that a column for the
    # query this context belongs to by the name +name+ exists, and return a
    # Mao::Filter::Column for that column.
    def method_missing(name, *args, &block)
      if args.length > 0
        raise ArgumentError, "args not expected in #where subclause"
      end

      if block
        raise ArgumentError, "block not expected in #where subclause"
      end

      unless @query.col_types[name]
        raise ArgumentError, "unknown column for #{@query.table}: #{name}"
      end

      if @explicit
        Column.new(:table => @query.table.to_sym, :name => name).freeze
      else
        Column.new(:name => name).freeze
      end
    end
  end
end

# vim: set sw=2 cc=80 et:
