# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/json_schema/schema_definition/results_extension"

module ElasticGraph
  module JsonSchema
    module SchemaDefinition
      RSpec.describe ResultsExtension do
        let(:fake_type_class) do
          ::Struct.new(
            :name,
            :indexing_field_type,
            :root_document_type_value,
            :abstract_value,
            :graphql_only_value,
            keyword_init: true
          ) do
            def root_document_type?
              root_document_type_value
            end

            def abstract?
              abstract_value
            end

            def graphql_only?
              graphql_only_value
            end

            def to_indexing_field_type
              indexing_field_type
            end
          end
        end

        let(:fake_indexing_field_type_class) do
          ::Struct.new(:json_schema, :field_metadata, keyword_init: true) do
            def to_json_schema
              json_schema
            end

            def json_schema_field_metadata_by_field_name
              field_metadata
            end
          end
        end

        let(:fake_merged_schema_class) do
          ::Struct.new(:json_schema_version, :json_schema, keyword_init: true)
        end

        def build_results(state:, derived_indexing_type_names: Set[])
          ::Object.new.tap do |results|
            results.extend(described_class)
            results.define_singleton_method(:state) { state }
            results.define_singleton_method(:derived_indexing_type_names) { derived_indexing_type_names }
          end
        end

        it "builds the current public JSON schema, exposes metadata helpers, and memoizes merged schemas" do
          widget_indexing_type = fake_indexing_field_type_class.new(
            json_schema: {"type" => "object"},
            field_metadata: {"id" => {"name_in_index" => "id"}}
          )

          widget_type = fake_type_class.new(
            name: "Widget",
            indexing_field_type: widget_indexing_type,
            root_document_type_value: true,
            abstract_value: false,
            graphql_only_value: false
          )
          derived_type = fake_type_class.new(
            name: "DerivedWidget",
            indexing_field_type: widget_indexing_type,
            root_document_type_value: true,
            abstract_value: false,
            graphql_only_value: false
          )
          graphql_only_type = fake_type_class.new(
            name: "GraphqlOnly",
            indexing_field_type: widget_indexing_type,
            root_document_type_value: false,
            abstract_value: false,
            graphql_only_value: true
          )
          query_type = fake_type_class.new(
            name: "Query",
            indexing_field_type: widget_indexing_type,
            root_document_type_value: false,
            abstract_value: false,
            graphql_only_value: false
          )

          setter_location = instance_double(::Thread::Backtrace::Location)
          state = ::Struct.new(
            :json_schema_version,
            :json_schema_version_setter_location,
            :object_types_by_name,
            :types_by_name,
            keyword_init: true
          ).new(
            json_schema_version: 3,
            json_schema_version_setter_location: setter_location,
            object_types_by_name: {
              "Widget" => widget_type,
              "DerivedWidget" => derived_type
            },
            types_by_name: {
              "Query" => query_type,
              "Widget" => widget_type,
              "DerivedWidget" => derived_type,
              "GraphqlOnly" => graphql_only_type
            }
          )

          results = build_results(state: state, derived_indexing_type_names: Set["DerivedWidget"])

          merged_schema = fake_merged_schema_class.new(
            json_schema_version: 3,
            json_schema: {"json_schema_version" => 3, "$defs" => {"Widget" => {"with_metadata" => true}}}
          )
          merger = instance_double(
            ElasticGraph::SchemaDefinition::Indexing::JSONSchemaWithMetadata::Merger,
            merge_metadata_into: merged_schema,
            unused_deprecated_elements: [:unused]
          )

          expect(ElasticGraph::SchemaDefinition::Indexing::JSONSchemaWithMetadata::Merger).to receive(:new).with(results).once.and_return(merger)
          expect(ElasticGraph::SchemaDefinition::Indexing::EventEnvelope).to receive(:json_schema).with(["Widget"], 3).once.and_return({"type" => "object"})

          expect(results.available_json_schema_versions).to eq(Set[3])
          expect(results.latest_json_schema_version).to eq(3)
          expect(results.json_schema_version_setter_location).to be(setter_location)
          expect(results.json_schema_field_metadata_by_type_and_field_name).to eq({"Widget" => {"id" => {"name_in_index" => "id"}}})
          expect(results.current_public_json_schema).to include(
            "$schema" => JSON_META_SCHEMA,
            JSON_SCHEMA_VERSION_KEY => 3
          )
          expect(results.current_public_json_schema.fetch("$defs")).to include(
            "ElasticGraphEventEnvelope" => {"type" => "object"},
            "Widget" => {"type" => "object"}
          )
          expect(results.unused_deprecated_elements).to eq([:unused])
          expect(results.json_schemas_for(3)).to eq({"json_schema_version" => 3, "$defs" => {"Widget" => {"with_metadata" => true}}})
          expect(results.json_schemas_for(3)).to eq({"json_schema_version" => 3, "$defs" => {"Widget" => {"with_metadata" => true}}})
        end

        it "raises when the requested JSON schema version is unavailable" do
          state = ::Struct.new(
            :json_schema_version,
            :json_schema_version_setter_location,
            :object_types_by_name,
            :types_by_name,
            keyword_init: true
          ).new(
            json_schema_version: 3,
            json_schema_version_setter_location: nil,
            object_types_by_name: {},
            types_by_name: {}
          )

          results = build_results(state: state)

          expect {
            results.json_schemas_for(2)
          }.to raise_error(Errors::NotFoundError, /requested json schema version \(2\) is not available/)
        end

        it "raises when json_schema_version has not been configured" do
          state = ::Struct.new(
            :json_schema_version,
            :json_schema_version_setter_location,
            :object_types_by_name,
            :types_by_name,
            keyword_init: true
          ).new(
            json_schema_version: nil,
            json_schema_version_setter_location: nil,
            object_types_by_name: {},
            types_by_name: {}
          )

          results = build_results(state: state)

          expect {
            results.current_public_json_schema
          }.to raise_error(Errors::SchemaError, /`json_schema_version` must be specified/)
        end
      end
    end
  end
end
