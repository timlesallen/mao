module Norm::Filter
  # If +obj+ is a Norm::Filter, call #finalize on it; otherwise, use
  # Norm.escape_literal to escape +obj.to_s+.
  def self.finalize_or_literal(obj)
    if obj.is_a? Norm::Filter
      obj.finalize
    else
      Norm.escape_literal(obj.to_s)
    end
  end

  # Generate the SQL for the finalized object +finalized+.  If +finalized+ is a
  # String, it's returned without modification.
  def self.sql(finalized)
    if finalized.is_a? String
      finalized
    else
      klass, *args = finalized
      Norm::Filter.const_get(klass).sql(*args)
    end
  end

  def initialize(options={})
    @options = options.freeze
  end

  attr_reader :options

  # Returns an AND filter where the current object is the LHS and +rhs+ is the
  # RHS.
  def and(rhs)
    Norm::Filter::Binary.new(:op => 'AND', :lhs => self, :rhs => rhs).freeze
  end

  # Returns an OR filter where the current object is the LHS and +rhs+ is the
  # RHS.
  def or(rhs)
    Norm::Filter::Binary.new(:op => 'OR', :lhs => self, :rhs => rhs).freeze
  end

  # Returns an equality binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def ==(rhs)
    Norm::Filter::Binary.new(:op => '=', :lhs => self, :rhs => rhs)
  end

  # Returns an inequality binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def !=(rhs)
    Norm::Filter::Binary.new(:op => '<>', :lhs => self, :rhs => rhs)
  end

  # Returns a greater-than binary filter where the current object is the LHS
  # and +rhs+ is the RHS.
  def >(rhs)
    Norm::Filter::Binary.new(:op => '>', :lhs => self, :rhs => rhs)
  end

  # Returns a greater-than-or-equal-to binary filter where the current object
  # is the LHS and +rhs+ is the RHS.
  def >=(rhs)
    Norm::Filter::Binary.new(:op => '>=', :lhs => self, :rhs => rhs)
  end

  # Returns a less-than binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def <(rhs)
    Norm::Filter::Binary.new(:op => '<', :lhs => self, :rhs => rhs)
  end

  # Returns a less-than-or-equal-to binary filter where the current object is
  # the LHS and +rhs+ is the RHS.
  def <=(rhs)
    Norm::Filter::Binary.new(:op => '<=', :lhs => self, :rhs => rhs)
  end

  class Column
    include Norm::Filter

    def finalize
      [:Column, @options[:name]]
    end

    def self.sql(name)
      Norm.quote_ident(name.to_s)
    end
  end

  class Binary
    include Norm::Filter

    def finalize
      [:Binary,
       @options[:op],
       Norm::Filter.finalize_or_literal(@options[:lhs]),
       Norm::Filter.finalize_or_literal(@options[:rhs])]
    end

    def self.sql(op, lhs, rhs)
      s = "("
      s << Norm::Filter.sql(lhs)
      s << " "
      s << op
      s << " "
      s << Norm::Filter.sql(rhs)
      s << ")"
      s
    end
  end
end

# vim: set sw=2 cc=80 et:
