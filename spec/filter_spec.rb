require 'spec_helper'

describe Mao::Filter do
  before { prepare_spec }

  let(:col_x) { Mao::Filter::Column.new(:name => :x) }
  let(:col_y) { Mao::Filter::Column.new(:name => :y) }

  describe ".finalize_or_literal" do
    context "with Mao::Filter" do
      before { expect(col_x).to receive(:finalize).
                   with(no_args).and_return("blah") }
      it { expect(Mao::Filter.finalize_or_literal(col_x)).to eq "blah" }
    end

    context "with non-Mao::Filter" do
      before { expect(Mao).to receive(:escape_literal).
                   with(42).and_return("ha") }
      it { expect(Mao::Filter.finalize_or_literal(42)).to eq "ha" }
    end
  end

  describe ".sql" do
    context "Arrays" do
      let(:klass) { double("klass") }
      before { expect(Mao::Filter).to receive(:const_get).
                 with(:Hullo).and_return(klass) }
      before { expect(klass).to receive(:sql).with(:mao).and_return :dengxiaoping }
      it { expect(Mao::Filter.sql([:Hullo, :mao])).to eq :dengxiaoping }
    end

    context "Strings" do
      it { expect(Mao::Filter.sql("BATTLE ROYALE")).to eq "BATTLE ROYALE" }
    end
  end

  describe "#and" do
    subject { col_x.and(col_y) }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "AND" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#or" do
    subject { col_x.or(col_y) }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "OR" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#==" do
    subject { col_x == col_y }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "=" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#!=" do
    subject { col_x != col_y }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "<>" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#>" do
    subject { col_x > col_y }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq ">" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#>=" do
    subject { col_x >= col_y }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq ">=" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#<" do
    subject { col_x < col_y }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "<" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#<=" do
    subject { col_x <= col_y }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "<=" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be col_y }
  end

  describe "#null?" do
    subject { col_x.null? }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "IS" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to be_nil }
  end

  describe "#in" do
    subject { col_x.in([1, 2, 3]) }

    it { is_expected.to be_an_instance_of Mao::Filter::Binary }
    it { expect(subject.options[:op]).to eq "IN" }
    it { expect(subject.options[:lhs]).to be col_x }
    it { expect(subject.options[:rhs]).to eq [1, 2, 3] }
  end
end

describe Mao::Filter::Column do
  before { prepare_spec }

  context "without table" do
    subject { Mao::Filter::Column.new(:name => :Margorth) }

    describe '#finalize' do
      subject { super().finalize }
      it { is_expected.to eq [:Column, :Margorth] }
    end
    it { expect(Mao::Filter.sql(subject.finalize)).to eq '"Margorth"' }
  end

  context "with table" do
    subject { Mao::Filter::Column.new(:table => :Lol, :name => :Margorth) }

    describe '#finalize' do
      subject { super().finalize }
      it { is_expected.to eq [:Column, :Lol, :Margorth] }
    end
    it { expect(Mao::Filter.sql(subject.finalize)).to eq '"Lol"."Margorth"' }
  end
end

describe Mao::Filter::Binary do
  before { prepare_spec }
  subject { Mao::Filter::Binary.new(:lhs => 42, :op => '=', :rhs => 42) }

  describe '#finalize' do
    subject { super().finalize }
    it { is_expected.to eq [:Binary, '=', "42", "42"] }
  end
  it { expect(Mao::Filter.sql(subject.finalize)).to eq "(42 = 42)" }
end

describe Mao::Filter::Table do
  before { prepare_spec }

  context "non-explicit" do
    let(:some) { Mao::Filter::Table.new(Mao.query(:some), false) }
    it { expect(some.value).to be_an_instance_of Mao::Filter::Column }
    it { expect(some.value.finalize).to eq [:Column, :value] }
  end

  context "explicit" do
    let(:some) { Mao::Filter::Table.new(Mao.query(:some), true) }
    it { expect(some.value).to be_an_instance_of Mao::Filter::Column }
    it { expect(some.value.finalize).to eq [:Column, :some, :value] }
  end

  context "non-extant" do
    let(:some) { Mao::Filter::Table.new(Mao.query(:some), false) }
    it { expect { some.blargh }.to raise_exception(ArgumentError) }
  end
end

# vim: set sw=2 cc=80 et:
