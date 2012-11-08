module Norm::Filter
  # If +obj+ is a Norm::Filter, call #sql on it; otherwise, use
  # Norm.escape_literal to escape +obj.to_s+.
  def self.sql_or_literal(obj)
    if obj.is_a? Norm::Filter
      obj.sql
    else
      Norm.escape_literal(obj.to_s)
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

  class Column
    include Norm::Filter

    def sql
      Norm.quote_ident(@options[:name].to_s)
    end
  end

  class Binary
    include Norm::Filter

    def sql
      s = "("
      s << Norm::Filter.sql_or_literal(@options[:lhs])
      s << " "
      s << @options[:op]
      s << " "
      s << Norm::Filter.sql_or_literal(@options[:rhs])
      s << ")"
      s
    end
  end
end

# vim: set sw=2 cc=80 et:
