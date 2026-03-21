# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/json_schema/schema_definition/factory_extension"

module ElasticGraph
  module JsonSchema
    module SchemaDefinition
      RSpec.describe FactoryExtension do
        let(:factory_class) do
          base_class = ::Class.new do
            def new_results
              ::Object.new
            end

            def new_schema_artifact_manager(*args, **kwargs)
              @last_schema_artifact_manager_args = args
              @last_schema_artifact_manager_kwargs = kwargs
              ::Object.new
            end

            attr_reader :last_schema_artifact_manager_args, :last_schema_artifact_manager_kwargs
          end

          ::Class.new(base_class) do
            prepend FactoryExtension
          end
        end

        it "extends results and schema artifact managers with JSON schema behavior" do
          factory = factory_class.new

          expect(factory.new_results).to be_a(ResultsExtension)

          manager = factory.new_schema_artifact_manager(:positional, key: "value")
          expect(manager).to be_a(SchemaArtifactManagerExtension)
          expect(factory.last_schema_artifact_manager_args).to eq([:positional])
          expect(factory.last_schema_artifact_manager_kwargs).to eq({key: "value"})
        end
      end
    end
  end
end
