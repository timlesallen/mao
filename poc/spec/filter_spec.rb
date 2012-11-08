require 'spec_helper'

describe Norm::Filter do
  before { prepare_spec }

  let(:col_x) { Norm::Filter::Column.new(:name => :x) }
  let(:col_y) { Norm::Filter::Column.new(:name => :y) }

  describe ".sql_or_literal" do
    context "with Norm::Filter" do
      before { col_x.should_receive(:sql).with(no_args).and_return("blah") }
      it { Norm::Filter.sql_or_literal(col_x).should eq "blah" }
    end

    context "with non-Norm::Filter" do
      before { Norm.should_receive(:escape_literal).
                   with("42").and_return("ha") }
      it { Norm::Filter.sql_or_literal(42).should eq "ha" }
    end
  end

  describe "#and" do
    subject { col_x.and(col_y) }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "AND" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#or" do
    subject { col_x.or(col_y) }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "OR" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#==" do
    subject { col_x == col_y }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "=" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#!=" do
    subject { col_x != col_y }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "<>" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#>" do
    subject { col_x > col_y }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq ">" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#>=" do
    subject { col_x >= col_y }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq ">=" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#<" do
    subject { col_x < col_y }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "<" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end

  describe "#<=" do
    subject { col_x <= col_y }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "<=" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be col_y }
  end
end

describe Norm::Filter::Column do
  before { prepare_spec }
  subject { Norm::Filter::Column.new(:name => :Margorth) }

  its(:sql) { should eq '"Margorth"' }
end

describe Norm::Filter::Binary do
  before { prepare_spec }
  subject { Norm::Filter::Binary.new(:lhs => 42, :op => '=', :rhs => 42) }

  its(:sql) { should eq "('42' = '42')" }
end

# vim: set sw=2 cc=80 et:
