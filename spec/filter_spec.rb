require 'spec_helper'

describe Norm::Filter do
  before { prepare_spec }

  let(:col_x) { Norm::Filter::Column.new(:name => :x) }
  let(:col_y) { Norm::Filter::Column.new(:name => :y) }

  describe ".finalize_or_literal" do
    context "with Norm::Filter" do
      before { col_x.should_receive(:finalize).
                   with(no_args).and_return("blah") }
      it { Norm::Filter.finalize_or_literal(col_x).should eq "blah" }
    end

    context "with non-Norm::Filter" do
      before { Norm.should_receive(:escape_literal).
                   with(42).and_return("ha") }
      it { Norm::Filter.finalize_or_literal(42).should eq "ha" }
    end
  end

  describe ".sql" do
    context "Arrays" do
      let(:klass) { double("klass") }
      before { Norm::Filter.should_receive(:const_get).
                 with(:Hullo).and_return(klass) }
      before { klass.should_receive(:sql).with(:mao).and_return :dengxiaoping }
      it { Norm::Filter.sql([:Hullo, :mao]).should eq :dengxiaoping }
    end

    context "Strings" do
      it { Norm::Filter.sql("BATTLE ROYALE").should eq "BATTLE ROYALE" }
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

  describe "#null?" do
    subject { col_x.null? }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "IS" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should be_nil }
  end

  describe "#in" do
    subject { col_x.in([1, 2, 3]) }

    it { should be_an_instance_of Norm::Filter::Binary }
    it { subject.options[:op].should eq "IN" }
    it { subject.options[:lhs].should be col_x }
    it { subject.options[:rhs].should eq [1, 2, 3] }
  end
end

describe Norm::Filter::Column do
  before { prepare_spec }

  context "without table" do
    subject { Norm::Filter::Column.new(:name => :Margorth) }
    its(:finalize) { should eq [:Column, :Margorth] }
    it { Norm::Filter.sql(subject.finalize).should eq '"Margorth"' }
  end

  context "with table" do
    subject { Norm::Filter::Column.new(:table => :Lol, :name => :Margorth) }
    its(:finalize) { should eq [:Column, :Lol, :Margorth] }
    it { Norm::Filter.sql(subject.finalize).should eq '"Lol"."Margorth"' }
  end
end

describe Norm::Filter::Binary do
  before { prepare_spec }
  subject { Norm::Filter::Binary.new(:lhs => 42, :op => '=', :rhs => 42) }

  its(:finalize) { should eq [:Binary, '=', "42", "42"] }
  it { Norm::Filter.sql(subject.finalize).should eq "(42 = 42)" }
end

describe Norm::Filter::Table do
  before { prepare_spec }

  context "non-explicit" do
    let(:some) { Norm::Filter::Table.new(Norm.query(:some), false) }
    it { some.value.should be_an_instance_of Norm::Filter::Column }
    it { some.value.finalize.should eq [:Column, :value] }
  end

  context "explicit" do
    let(:some) { Norm::Filter::Table.new(Norm.query(:some), true) }
    it { some.value.should be_an_instance_of Norm::Filter::Column }
    it { some.value.finalize.should eq [:Column, :some, :value] }
  end

  context "non-extant" do
    let(:some) { Norm::Filter::Table.new(Norm.query(:some), false) }
    it { expect { some.blargh }.to raise_exception(ArgumentError) }
  end
end

# vim: set sw=2 cc=80 et:
