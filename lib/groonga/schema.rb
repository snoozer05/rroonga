# -*- coding: utf-8 -*-
#
# Copyright (C) 2009  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


module Groonga

  # groongaのスキーマ（データ構造）を管理するクラス。
  #
  # Groonga::Schemaを使うことにより簡単にテーブルやカラムを
  # 追加・削除することができる。
  #
  # http://qwik.jp/senna/senna2.files/rect4605.png
  # のようなスキーマを定義する場合は以下のようになる。
  #
  #   Groonga::Schema.define do |schema|
  #     schema.create_table("items") do |table|
  #       table.short_text("title")
  #     end
  #
  #     schema.create_table("users") do |table|
  #       table.short_text("name")
  #     end
  #
  #     schema.create_table("comments") do |table|
  #       table.reference("item", "items")
  #       table.reference("author", "users")
  #       table.text("content")
  #       table.time("issued")
  #     end
  #   end
  class Schema
    class << self

      # call-seq:
      #   Groonga::Schema.define(options={}) {|schema| ...}
      #
      # スキーマを定義する。ブロックにはGroonga::Schemaオブ
      # ジェクトがわたるので、そのオブジェクトを利用してスキー
      # マを定義する。
      #
      # _options_に指定可能な値は以下の通り。
      #
      # [+:context+]
      #   スキーマ定義時に使用するGroonga::Contextを指定する。
      #   省略した場合はGroonga::Context.defaultを使用する。
      def define(options={})
        schema = new(options)
        yield(schema)
        schema.define
      end

      # call-seq:
      #   Groonga::Schema.create_table(name, options={}) {|table| ...}
      #
      # 名前が_name_のテーブルを作成する。以下の省略形。
      #
      #   Groonga::Schema.define do |schema|
      #     schema.create_table(name, options) do |table|
      #       ...
      #     end
      #   end
      #
      # ブロックにはGroonga::Schema::TableDefinitionオブジェ
      # クトがわたるので、そのオブジェクトを利用してテーブル
      # の詳細を定義する。
      #
      # _options_に指定可能な値は以下の通り。
      #
      # [+:context+]
      #   スキーマ定義時に使用するGroonga::Contextを指定する。
      #   省略した場合はGroonga::Context.defaultを使用する。
      #
      # [+:path+]
      #   テーブルを保存するパスを指定する。パスを指定すると
      #   永続テーブルになる。
      #
      # [+:persistent+]
      #   テーブルを永続テーブルとする。+:path:+を省略した場
      #   合はパス名は自動的に作成される。デフォルトでは永続
      #   テーブルとなる。
      #
      # [+:value_type+]
      #   値のサイズを指定する。デフォルトは0。 # FIXME
      def create_table(name, options={}, &block)
        define do |schema|
          schema.create_table(name, options, &block)
        end
      end

      # スキーマの内容を文字列で返す。返された値は
      # Groonga::Schema.restoreすることによりスキーマ内に組
      # み込むことができる。
      #
      #   dump.rb:
      #     File.open("/tmp/groonga-schema.rb", "w") do |schema|
      #       dumped_text = Groonga::Schema.dump
      #     end
      #
      #   restore.rb:
      #     dumped_text = Groonga::Schema.dump
      #     Groonga::Database.create(:path => "/tmp/new-db.grn")
      #     Groonga::Schema.restore(dumped_text)
      #
      # _options_に指定可能な値は以下の通り。
      #
      # [+:context+]
      #   スキーマ定義時に使用するGroonga::Contextを指定する。
      #   省略した場合はGroonga::Context.defaultを使用する。
      def dump(options={})
        Dumper.new(options).dump
      end

      # Groonga::Schema.dumpで文字列化したスキーマを組み込む。
      def restore(dumped_text, options={})
        define(options) do |schema|
          schema.load(dumped_text)
	end
      end

      def normalize_type(type) # :nodoc:
        return type if type.nil?
        return type if type.is_a?(Groonga::Object)
        case type.to_s
        when "string"
          "ShortText"
        when "text"
          "Text"
        when "int", "integer"
          "Int32"
        when "float"
          "Float"
        when "decimal"
          "Int64"
        when "datetime", "timestamp", "time", "date"
          "Time"
        when "binary"
          "LongText"
        when "boolean"
          "Bool"
        else
          type
        end
      end
    end

    # スキーマ定義を開始する。
    #
    # _options_に指定可能な値は以下の通り。
    #
    # [+:context+]
    #   スキーマ定義時に使用するGroonga::Contextを指定する。
    #   省略した場合はGroonga::Context.defaultを使用する。
    def initialize(options={})
      @options = (options || {}).dup
      @definitions = []
    end

    # 定義されたスキーマ定義を実際に実行する。
    def define
      @definitions.each do |definition|
        definition.define
      end
    end

    # Groonga::Schema.dumpで返されたスキーマの内容を読み込む。
    #
    # 読み込まれた内容は#defineを呼び出すまでは実行されない
    # ことに注意すること。
    def load(dumped_text)
      instance_eval(dumped_text)
    end

    # 名前が_name_のテーブルを作成する。
    #
    # 作成したテーブルは#defineを呼び出すまでは実行されない
    # ことに注意すること。
    #
    # _options_に指定可能な値は以下の通り。
    #
    # [+:context+]
    #   スキーマ定義時に使用するGroonga::Contextを指定する。
    #   省略した場合はGroonga::Schema.newで指定した
    #   Groonga::Contextを使用する。Groonga::Schema.newで指
    #   定していない場合はGroonga::Context.defaultを使用する。
    #
    # [+:path+]
    #   テーブルを保存するパスを指定する。パスを指定すると
    #   永続テーブルになる。
    #
    # [+:persistent+]
    #   テーブルを永続テーブルとする。+:path:+を省略した場
    #   合はパス名は自動的に作成される。デフォルトでは永続
    #   テーブルとなる。
    #
    # [+:value_size+]
    #   値のサイズを指定する。デフォルトは0。
    def create_table(name, options={})
      definition = TableDefinition.new(name, @options.merge(options || {}))
      yield(definition)
      @definitions << definition
    end

    def change_table(table_name, options={})
      options = @options.merge(options || {}).merge(:change => true)
      definition = TableDefinition.new(name, options)
      yield(definition)
      @definitions << definition
    end

    class TableDefinition
      def initialize(name, options)
        @name = name
        @name = @name.to_s if @name.is_a?(Symbol)
        @columns = []
        @options = options
        @table_type = table_type
      end

      def define
        if @options[:change]
          table = context[@name]
        else
          table = @table_type.create(create_options)
        end
        @columns.each do |column|
          column.define(table)
        end
        table
      end

      def column(name, type, options={})
        column = self[name] || ColumnDefinition.new(name, options)
        column.type = type
        column.options.merge!(options)
        @columns << column unless @columns.include?(column)
        self
      end

      def integer32(name, options={})
        column(name, "Int32", options)
      end
      alias_method :integer, :integer32
      alias_method :int32, :integer32

      def integer64(name, options={})
        column(name, "Int64", options)
      end
      alias_method :int64, :integer64

      def unsigned_integer32(name, options={})
        column(name, "UInt32", options)
      end
      alias_method :unsigned_integer, :unsigned_integer32
      alias_method :uint32, :unsigned_integer32

      def unsigned_integer64(name, options={})
        column(name, "UInt64", options)
      end
      alias_method :uint64, :unsigned_integer64

      def float(name, options={})
        column(name, "Float", options)
      end

      def time(name, options={})
        column(name, "Time", options)
      end

      def short_text(name, options={})
        column(name, "ShortText", options)
      end
      alias_method :string, :short_text

      def text(name, options={})
        column(name, "Text", options)
      end

      def long_text(name, options={})
        column(name, "LongText", options)
      end

      def reference(name, table, options={})
        column(name, table, options)
      end

      def index(name, target_column, options={})
        column = self[name] || IndexColumnDefinition.new(name, options)
        column.target = target_column
        column.options.merge!(options)
        @columns << column unless @columns.include?(column)
        self
      end

      def [](name)
        @columns.find {|column| column.name == name}
      end

      private
      def table_type
        type = @options[:type]
        case type
        when :array, nil
          Groonga::Array
        when :hash
          Groonga::Hash
        when :patricia_trie
          Groonga::PatriciaTrie
        else
          raise ArgumentError, "unknown table type: #{type.inspect}"
        end
      end

      def create_options
        common = {
          :name => @name,
          :path => @options[:path],
          :persistent => persistent?,
          :value_type => @options[:value_type],
          :context => context,
        }
        key_support_table_common = {
          :key_type => Schema.normalize_type(@options[:key_type]),
          :default_tokenizer => @options[:default_tokenizer],
        }

        if @table_type == Groonga::Array
          common
        elsif @table_type == Groonga::Hash
          common.merge(key_support_table_common)
        elsif @table_type == Groonga::PatriciaTrie
          options = {
            :key_normalize => @options[:key_normalize],
            :key_with_sis => @options[:key_with_sis],
          }
          common.merge(key_support_table_common).merge(options)
        else
          raise ArgumentError, "unknown table type: #{@table_type.inspect}"
        end
      end

      def persistent?
        @options[:persistent].nil? ? true : @options[:persistent]
      end

      def context
        @options[:context] || Groonga::Context.default
      end
    end

    class ColumnDefinition
      attr_accessor :name, :type
      attr_reader :options

      def initialize(name, options={})
        @name = name
        @name = @name.to_s if @name.is_a?(Symbol)
        @options = (options || {}).dup
        @type = nil
      end

      def define(table)
        table.define_column(@name,
                            Schema.normalize_type(@type),
                            @options)
      end
    end

    class IndexColumnDefinition
      attr_accessor :name, :target
      attr_reader :options

      def initialize(name, options={})
        @name = name
        @name = @name.to_s if @name.is_a?(Symbol)
        @options = (options || {}).dup
        @target = nil
      end

      def define(table)
        target = @target
        target = context[target] unless target.is_a?(Groonga::Object)
        index = table.define_index_column(@name,
                                          target.table,
                                          @options)
        index.source = target
        index
      end

      private
      def context
        @options[:context] || Groonga::Context.default
      end
    end

    class Dumper
      def initialize(options={})
        @options = (options || {}).dup
      end

      def dump
        context = @options[:context] || Groonga::Context.default
        database = context.database
        return nil if database.nil?

        reference_columns = []
        definitions = []
        database.each do |object|
          next unless object.is_a?(Groonga::Table)
          schema = "create_table(#{object.name.inspect}) do |table|\n"
          object.columns.sort_by {|column| column.local_name}.each do |column|
            if column.range.is_a?(Groonga::Table)
              reference_columns << column
            else
              type = column_method(column)
              name = column.local_name
              schema << "  table.#{type}(#{name.inspect})\n"
            end
          end
          schema << "end"
          definitions << schema
        end

        reference_columns.group_by do |column|
          column.table
        end.each do |table, columns|
          schema = "change_table(#{table.name.inspect}) do |table|\n"
          columns.each do |column|
            name = column.local_name
            reference = column.range
            schema << "  table.reference(#{name.inspect}, " +
                                        "#{reference.name.inspect})\n"
          end
          schema << "end"
          definitions << schema
        end

        if definitions.empty?
          ""
        else
          definitions.join("\n\n") + "\n"
        end
      end

      private
      def column_method(column)
        range = column.range
        case range.name
        when "Int32"
          "integer32"
        when "Int64"
          "integer64"
        when "UInt32"
          "unsigned_integer32"
        when "UInt64"
          "unsigned_integer64"
        when "Float"
          "float"
        when "Time"
          "time"
        when "ShortText"
          "short_text"
        when "Text"
          "text"
        when "LongText"
          "long_text"
        else
          raise ArgumentError, "unsupported column: #{column.inspect}"
        end
      end
    end
  end
end