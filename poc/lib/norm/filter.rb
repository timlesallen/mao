module Norm::Filter
  def initialize(options={})
    @options = options.freeze
  end

  # Returns a new instance of this class with +options+ merged into the options
  # of this object.
  def with_options(options)
    self.class.new(@options.merge(options)).freeze
  end

  # Returns an AND filter where the current object is the LHS and +rhs+ is the
  # RHS.
  def and(rhs)
    Norm::Filter::Logic.new(:op => 'AND', :lhs => self, :rhs => rhs).freeze
  end

  # Returns an OR filter where the current object is the LHS and +rhs+ is the
  # RHS.
  def or(rhs)
    Norm::Filter::Logic.new(:op => 'OR', :lhs => self, :rhs => rhs).freeze
  end

  # Returns an equality binary filter where the current object is the LHS and
  # +rhs+ is the RHS.
  def ==(rhs)
    Norm::Filter::Binary.new(:lhs => self, :op => '=', :rhs => rhs)
  end

  class Column
    include Norm::Filter

    def finalize
      @options[:name]
    end
  end

  class Binary
    include Norm::Filter

    def finalize
      # TODO: recursively walk and finalize
      [@options[:lhs], @options[:op], @options[:rhs]]
    end
  end

  class Logic
    include Norm::Filter

    def finalize
      [@options[:lhs], @options[:op], @options[:rhs]]
    end
  end
end

# vim: set sw=2 cc=80 et:
