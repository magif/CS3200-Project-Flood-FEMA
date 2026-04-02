import json

def generate_mysql_schema(json_filepath, table_name):
    with open(json_filepath, 'r') as file:
        data = json.load(file)
        
    fields = data.get('OpenFemaDataSetFields', [])
    
    # Start building the SQL statement
    sql = f"CREATE TABLE {table_name} (\n"
    
    columns = []
    primary_key = None
    
    for field in fields:
        name = field['name']
        data_type = field['type'].lower()
        is_pk = field.get('primaryKey', False)
        
        # Map OpenFEMA types to MySQL types
        if data_type == 'text':
            mysql_type = 'VARCHAR(255)'
        elif data_type == 'datetime':
            mysql_type = 'DATETIME'
        elif data_type == 'date':
            mysql_type = 'DATE'
        elif 'decimal' in data_type:
            mysql_type = data_type.upper()
        elif data_type == 'smallint':
            mysql_type = 'SMALLINT'
        elif data_type == 'integer':
            mysql_type = 'INT'
        elif data_type == 'bigint':
            mysql_type = 'BIGINT'
        elif data_type == 'boolean':
            mysql_type = 'BOOLEAN'
        else:
            mysql_type = 'VARCHAR(255)' # Fallback
            
        columns.append(f"    {name} {mysql_type}")
        
        if is_pk:
            primary_key = name

    # Join columns and add the primary key if it exists
    sql += ",\n".join(columns)
    
    if primary_key:
        sql += f",\n    PRIMARY KEY ({primary_key})"
        
    sql += "\n);"
    
    return sql

# Generate and print the blueprint
sql_statement = generate_mysql_schema('OpenFemaDataSetFields.json', 'fima_nfip_claims')
print(sql_statement)