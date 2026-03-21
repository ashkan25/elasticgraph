# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/json_schema/schema_definition/results_extension"
require "elastic_graph/json_schema/schema_definition/schema_artifact_manager_extension"

module ElasticGraph
  module JsonSchema
    module SchemaDefinition
      # Extension module applied to `ElasticGraph::SchemaDefinition::Factory` to wire up
      # JSON Schema support on Results and SchemaArtifactManager instances.
      #
      # @api private
      module FactoryExtension
        # Creates a new Results instance with JSON Schema extensions.
        #
        # @return [ElasticGraph::SchemaDefinition::Results] the created results instance
        def new_results
          super.tap do |results|
            results.extend ResultsExtension
          end
        end

        # Creates a new SchemaArtifactManager instance with JSON Schema extensions.
        #
        # @return [ElasticGraph::SchemaDefinition::SchemaArtifactManager] the created artifact manager
        def new_schema_artifact_manager(...)
          super.tap do |manager|
            manager.extend SchemaArtifactManagerExtension
          end
        end
      end
    end
  end
end
