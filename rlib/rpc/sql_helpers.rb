#
# Used to create queries on the fly, which allows us to limit responses to a smaller subset of fields
# These are to be deprecated, as it is clearer to write each query, and accept the inefficencies.
module SQL_Helpers
  require 'wikk_sql'

  # Methods for processing argument lists.

  # Validate that we are permitted to view the field requested
  def acceptable(field:, acceptable_list: [])
    raise ArgumentError, "Argument #{field} is not in acceptable list" unless acceptable_list.include?(field)
  end

  # Validate we are permitted to view all fields requested
  def acceptable_list(list:, acceptable_list: [])
    if list != nil
      list.each do |k, _v|
        acceptable(field: k, acceptable_list: acceptable_list)
      end
    end
  end

  # Run a SQL query, of return the response as a hash
  def sql_query(query:, with_tables: false)
    response = {}
    rows = []
    WIKK::SQL.connect(@db_config) do |sql|
      sql.each_hash(query, with_tables) do |row|
        rows << row
      end
      response['rows'] = rows
      response['affected_rows'] = sql.affected_rows
    end
    return response
  end

  # SELECT SQL contructed query , against a single table, returning the result as a hash
  def sql_single_table_select(table:, select:, where:, order_by: '', with_tables: false)
    response = {}
    rows = []
    WIKK::SQL.connect(@db_config) do |sql|
      sql.each_hash("SELECT #{select} FROM #{table} #{where} #{order_by}", with_tables) do |row|
        rows << row
      end
      response['rows'] = rows
      response['affected_rows'] = sql.affected_rows
    end
    return response
  end

  # SELECT SQL contructed query , against multiple tables, returning the result as a hash
  def sql_multi_table_select(table:, select:, where:, order_by: '', with_tables: true)
    response = {}
    rows = []
    WIKK::SQL.connect(@db_config) do |sql|
      sql.each_hash("SELECT #{select} FROM #{table} #{where} #{order_by}", with_tables) do |row|
        rows << row
      end
      response['rows'] = rows
      response['affected_rows'] = sql.affected_rows
    end
    return response
  end

  # UPDATE SQL contructed query , against a single tables
  def sql_single_table_update(table:, set:, where: )
    response = {}
    WIKK::SQL.connect(@db_config) do |sql|
      sql.query <<~SQL
        UPDATE #{table} SET #{set} #{where}
      SQL
      response['rows'] = []
      response['affected_rows'] = sql.affected_rows
    end
    return response
  end

  # Build a SELECT field list
  def to_result(result:, acceptable_list: [])
    result_strings = []
    if result != nil
      result.each do |v|
        acceptable(field: v, acceptable_list: acceptable_list)
        result_strings << "#{v}"
      end
    end
    return result_strings.length > 0 ? result_strings.join(', ') : acceptable_list.join(', ')
  end

  # Build a WHERE component
  def to_where(select_on:, acceptable_list: [])
    where_strings = []
    if select_on != nil
      select_on.each do |k, v|
        acceptable(field: k, acceptable_list: acceptable_list)
        where_strings << "#{k} = '#{WIKK::SQL.escape(v.to_s)}'"
      end
    end
    return where_strings.length > 0 ? (' where ' + where_strings.join(' and ')) : ''
  end

  # Built a SET component, quoting the assigned string
  def to_set(set:, acceptable_list: [])
    set_strings = []
    if set != nil
      set.each do |k, v|
        acceptable(field: k, acceptable_list: acceptable_list)
        set_strings << "#{k} = '#{WIKK::SQL.escape(v)}'" if v != nil
      end
    end
    return set_strings.length > 0 ? set_strings.join(', ') : ''
  end

  # Build a GROUP BY component
  def group_by_table(sql_response:, primary_table_key:, secondary_table:)
    grouped_response = {}
    primary_table, _primary_key = primary_table_key.split('.')
    sql_response['rows'].each do |row|
      primary_key_value = row[primary_table_key] # Grouping on this value

      grouped_response[primary_key_value] ||= { secondary_table => [] } # Then in secondary array
      secondary_record = {} # Collect secondary tables values in here

      row.each do |k, v|
        table_name, field_name = k.split('.')
        grouped_response[primary_key_value][field_name] = v if table_name == primary_table
        secondary_record[field_name] = v if table_name == secondary_table
      end
      grouped_response[primary_key_value][secondary_table] << secondary_record
    end
    new_rows = []
    grouped_response.each { |_k, v| new_rows << v }
    return { 'rows' => new_rows, 'affected_rows' => new_rows.length }
  end

  # Build an ORDER BY component
  def to_order(order_by: nil, acceptable_list: [])
    order_by_strings = []
    if order_by != nil
      order_by.each do |v|
        acceptable(field: v, acceptable_list: acceptable_list)
        order_by_strings << "#{v}"
      end
    end
    return order_by_strings.length > 0 ? (' order by ' + order_by_strings.join(', ')) : ''
  end
end
