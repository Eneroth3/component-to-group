# frozen_string_literal: true

module Eneroth
  module ComponentToGroup
    # Convert components to groups.
    #
    # @param components Array<Sketchup::ComponentInstance>
    def self.convert_to_groups(components)
      components.group_by(&:definition).each do |definition, instances|
        first_group = instances.first.parent.entities.add_group
        first_group.entities.add_instance(definition, IDENTITY).explode
        mimic(first_group, instances.first)
        mimic_definition(first_group.definition, definition)

        instances[1..-1].each do |instance|
          group = instance.parent.entities.add_instance(first_group.definition,
                                                        instance.transformation)
          mimic(group, instance)
        end

        instances.each(&:erase!)
      end
    end

    # Copy instance properties over from reference to a target, making target
    # mimic the reference.
    #
    # @param target [Sketchup::ComponentInstance, Sketchup::Group]
    # @param reference [Sketchup::ComponentInstance, Sketchup::Group]
    def self.mimic(target, reference)
      target.layer = reference.layer
      target.material = reference.material
      target.transformation = reference.transformation
      # TODO: Copy glue to once supported by API.
      copy_attributes(target, reference)
    end

    # Copy definition properties over from reference to target, making target
    # mimic the reference.
    #
    # @param target [Sketchup::ComponentDefimition]
    # @param reference [Sketchup::ComponentDefinition]
    def self.mimic_definition(target, reference)
      target.behavior.always_face_camera =
        reference.behavior.always_face_camera?
      target.behavior.cuts_opening = reference.behavior.cuts_opening?
      target.behavior.is2d = reference.behavior.is2d?
      target.behavior.no_scale_mask = reference.behavior.no_scale_mask?
      target.behavior.shadows_face_sun = reference.behavior.shadows_face_sun?
      target.behavior.snapto = reference.behavior.snapto
      copy_attributes(target, reference)
    end

    # Copy attributes from one entity to another.
    #
    # @param target [Sketchup::Entity]
    # @param reference [Sketchup::Entity]
    def self.copy_attributes(target, reference)
      # Entity#attribute_dictionaries returns nil instead of empty array, GAH!
      (reference.attribute_dictionaries || []).each do |attr_dict|
        # Private SketchUp dictionary.
        next if attr_dict.name == "GSU_ContributorsInfo"

        attr_dict.each_pair { |k, v| target.set_attribute(attr_dict.name, k, v) }
        copy_attributes(target.attribute_dictionaries[attr_dict.name], attr_dict)
      end
    end

    # Get selected components in model.
    #
    # @return Array<Sketchup::ComponentInstance>
    def self.selected_components
      Sketchup.active_model.selection.grep(Sketchup::ComponentInstance)
    end

    unless @loaded
      @loaded = true

      command = UI::Command.new("Component to Group") do
        model = Sketchup.active_model
        model.start_operation("Component to Group", true)
        convert_to_groups(selected_components)
        model.commit_operation
      end

      UI.add_context_menu_handler do |menu|
        next if selected_components.empty?

        menu.add_separator
        menu.add_item(command)
      end
    end
  end
end
