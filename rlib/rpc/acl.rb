# Store acl for each group of users, for each action in a class.method
# ACL is an array of fields that the user in the group can specify.
class ACL
  def initialize
    # Indexed by class, method, and users group, to get acl array.
    @acl = {}
  end

  # @param class_name [String] Remate class we are in
  # @param method_name [String] Remote method we are in
  # @param action [String] Might need to do more than one thing in a method
  # @param group_name [String] Classify authorization using named groups
  def get(class_name:, method_name:, action:, group_name: )
    index = "#{class_name}.#{method_name}.#{action}.#{group_name}"
    @acl[index]
  end

  # @param class_name [String] Remote class we are in
  # @param method_name [String] Remote method we are in
  # @param action [String] Might need to do more than one thing in a method
  # @param group_name [String] Classify authorization using named groups
  # @param acl [Array[String]] For the SQL case, the strings in the array would be field names
  def register(class_name:, method_name:, action:, group_name:, acl:)
    index = "#{class_name}.#{method_name}.#{action}.#{group_name}"
    @acl[index] = acl
  end
end
