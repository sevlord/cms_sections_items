class Section < ActiveRecord::Base
  has_many :children, :class_name => 'Section', :foreign_key => 'parent_id', :order => 'position'
  belongs_to :parent, :class_name => 'Section', :foreign_key => 'parent_id'

  has_many :items, :foreign_key => 'section_id', :order => 'position'


  attr_accessible :name, :level, :short_name, :alias, :parent_id, :hidden, :description
  attr_accessor :can_be_shifted

  validates_format_of :alias, :with => /^[0-9a-z_-]+$/, :message => "alias must consist only english letters, digits and underscore sign"
  validates_length_of :alias, :in => 1..40
  validates_length_of :name, :in => 1..120
  validates_length_of :short_name, :in => 1..40
  validates_length_of :description, :maximum => 1200
  validates_presence_of :name, :short_name, :alias, :position, :level
  validates_uniqueness_of :alias, :scope => :parent_id, :message => "alias must be unique within the scope of its parent section"





  # TODO: write unit tests for model and controller after MacOS
  # TODO: items' file upload after MacOS
  # TODO: localization?


  class << self

    def tabulated_sections(sections = self.order(:position), tab = "&nbsp;")
      sections.map! { |e| [(tab * 2 * e[:level] + e.name).html_safe, e[:id]] }
    end


    def tabulated_without_descendants_of(section)
      all_sections = self.order(:position)
      sections_without_descendants = all_sections - section.with_descendants
      tabulated_sections(sections_without_descendants)
    end





    def update_with_shift(attributes, id)
      section = Section.find id

      old_parent_id = section[:parent_id]
      old_position = section[:position]
      old_level = section[:level]
      descendants = section.with_descendants
      descendants_ids = descendants.map(&:id)

      must_shift = old_parent_id.to_i != attributes[:parent_id].to_i

      section.attributes = attributes

      if section.valid?
        section.save

        if must_shift
          if section[:parent_id].nil?
            new_level = 1
            new_position = Section.maximum('position').to_i + 1 - descendants.length
          else
            new_parent = Section.find_by_id(section[:parent_id])
            new_level = new_parent[:level] + 1
            new_position = new_parent[:position] + 1
            new_position -= descendants.length if new_parent[:position] > old_position
          end

          # shift back all following sections
          Section.
              where('position >= ? AND id NOT IN (?)', old_position, descendants_ids).
              update_all(["position = position - ?", descendants.length.to_s])

          # shift forward all sections after new place
          Section.
              where('position >= ? AND id NOT IN (?)', new_position, descendants_ids).
              update_all(["position = position + ?", descendants.length])

          # shift updated branch into empty place
          position_difference = new_position - old_position
          level_difference = new_level - old_level
          Section.where('id IN (?)', descendants_ids).update_all(["position = position + ?", position_difference])
          Section.where('id IN (?)', descendants_ids).update_all(["level = level + ?", level_difference])
        end
      end

      section
    end



    def create_with_shift(attributes)
      section = Section.new
      section.attributes = attributes

      if section[:parent_id].nil?
        section[:level] = 1
        section[:position] = Section.maximum('position').to_i + 1
        must_shift = false
      else
        parent_section = Section.find_by_id(section[:parent_id])
        section[:level] = parent_section[:level] + 1
        section[:position] = parent_section[:position] + 1
        must_shift = true
      end

      if section.save and must_shift
        Section.
            where('position >= ? AND id <> ?', section[:position], section[:id]).
            update_all("position = position + 1")
      end

      section
    end



    def shifting_array(direction)
      case direction
        when "up"
          directional = {:condition => "<", :ordering => "DESC", :next => -1}
        when "down"
          directional = {:condition => ">", :ordering => "ASC", :next => 1}
        else
          raise WrongDirectionError
      end
      directional
    end

  end






  def shift(direction)
    directional = Section.shifting_array(direction)

    section = self
    if section.can_be_shifted? directional[:condition]
      next_section = Section.
          where(:level => section[:level]).
          where(:parent_id => section[:parent_id]).
          where("position #{directional[:condition]} ?", section[:position]).
          order("position #{directional[:ordering]}").
          first

      Section.
          where('id IN (?)', section.with_descendants.map(&:id)).
          update_all(["position = position + ?", directional[:next] * next_section.with_descendants.length])

      Section.
          where('id IN (?)', next_section.with_descendants.map(&:id)).
          update_all(["position = position + ?", -1 * directional[:next] * section.with_descendants.length])
    else
      return false
    end

    next_section
  end



  def can_be_shifted?(condition)
    Section.
        where(:level => self[:level]).
        where(:parent_id => self[:parent_id]).
        where("position #{condition} ?", self[:position]).
        count > 0
  end





  def destroy_with_shift
    descendants_length = self.with_descendants.length
    all_deleted = self.with_descendants.map {|descendant| true if descendant.delete}.all?

    if all_deleted
      Section.
        where('position >= ?', self[:position] + descendants_length).
        update_all(["position = position - ?", descendants_length])
    else
      false
    end
  end




  def descendants
    self.children.map { |c| [c] + c.descendants }
  end

  def with_descendants
    [self] + self.descendants.flatten
  end

  def ancestors
    node, nodes = self, []
    nodes << node = node.parent while node.parent
    nodes
  end
end
