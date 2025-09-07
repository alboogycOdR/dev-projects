//+------------------------------------------------------------------+
//|                                                    CDatabase.mqh |
//|                                           Copyright 2022, denkir |
//|                             https://www.mql5.com/ru/users/denkir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, denkir"
#property link      "https://www.mql5.com/ru/users/denkir"
//--- include
#include <Generic\HashSet.mqh>
#include <Arrays\ArrayString.mqh>
//+------------------------------------------------------------------+
//| Class CDatabase.                                                 |
//| Appointment: Class database operations.                          |
//|              Derives from class CObject.                         |
//+------------------------------------------------------------------+
class CDatabase : public CObject
   {
      //--- === Data members === ---
   private:
      string         m_name;
      int            m_handle;
      uint           m_flags;
      CHashSet<string>   m_table_names;
      string         m_curr_table_name;
      int            m_sql_request_ha;
      string         m_sql_request;
      //--- === Methods === ---
   public:
      //--- constructor/destructor
      void           CDatabase(void);
      void          ~CDatabase(void) {};
      //--- API MQL5 functions
      bool           Open(const string _file_name, const uint _flags);
      void           Close(void) const;
      bool           TransactionBegin(void);
      bool           TransactionCommit(void);
      bool           TransactionRollback(void);
      bool           Select(const string _sql_request);
      //--- get
      string         Name(void) const;
      int            Handle(void) const;
      uint           Flags(void) const;
      CHashSet<string> *TableNames(void);
      int            SqlRequestHandle(void) const;
      string         SqlRequest(void) const;
      //--- service
      bool           Structure(const string _name, const bool _is_temp=false);
      //--- tables
      bool           SelectTable(const string _table_name, const bool _is_temp=false);
      bool           CreateTable(const string _table_name, const string &_col_names[],
                                 const bool _not_exists=true, const bool _is_temp=false);
      bool           CreateTableAs(const string _table_name, const string _sql_request,
                                   const bool _not_exists=true, const bool _is_temp=false);
      bool           DropTable(const string _table_name);
      bool           DropCurrentTable(void);
      bool           TableExists(const string _table_name);
      long           ExportTable(const string _file_name, const uint _flags,
                                 const string _separator);
      long           ImportTable(const string _table_name, const string _file_name, const uint _flags,
                                 const string _separator=";", const ulong _rows_to_skip=0,
                                 const string  _skip_comments=NULL);
      bool           RenameTable(const string _new_name);
      bool           InsertSingleRow(const string &_col_names[], const string &_col_vals[]);
      bool           InsertMultipleRows(const string &_col_names[], const CArrayString &_rows_arr);
      bool           Update(const string &_col_names[], const string &_col_vals[],
                            const string _where_cond);
      bool           EmptyTable(void);
      bool           Delete(const string _where_cond);
      bool           Replace(const string &_col_names[], const string &_col_vals[]);
      bool           AddColumn(const string &_col_definition);
      bool           RenameColumn(const string _curr_name, const string _new_name);
      long           PrintTable(const uint _flags=0) const;
      bool           SelectFrom(const string &_col_names[]);
      bool           SelectFromGroupBy(const string &_col_names[], const string &_group_names[]);
      bool           SelectFromOrderedBy(const string &_col_names[], const string &_ord_names[]);
      bool           SelectDistinctFrom(const string &_col_names[]);
      bool           SelectDistinctFromOrderedBy(const string &_col_names[], const string &_ord_names[]);
      bool           SelectFromWhere(const string &_col_names[], const string _where_cond);
      bool           SelectFromWhereOrderedBy(const string &_col_names[], const string _where_cond,
                                              const string &_ord_names[]);
      bool           InnerJoin(const string &_col_names[], const string _other_table,
                               const string _join_cond);
      bool           LeftJoin(const string &_col_names[], const string _other_table,
                              const string _join_cond);
      bool           CrossJoin(const string &_col_names[], const string _other_table);
      bool           SelfJoin(const string &_col_names[], const string _from,
                              const string _where_cond);
      bool           FullOuterJoin(const string &_col_names[], const string _other_table,
                                   const string _join_cond);
      bool           Union(const string &_col_names[], const string _where_cond1,
                           const string _other_table, const string &_other_col_names[],
                           const string _where_cond2, const bool _all=false);
      bool           Except(const string &_col_names[], const string _other_table,
                            const string &_other_col_names[]);
      bool           Intersect(const string &_col_names[], const string _other_table,
                               const string &_other_col_names[]);
      bool           ListTables(CArrayString &_tables_list, const bool _to_print=false);
      //--- sql request
      bool           CreateSqlRequest(const string _sql_request);
      bool           ExecuteSqlRequest(void);
      template<typename T>
      bool           SqlRequestBind(const int _index, const T _val);
      template<typename T>
      bool           SqlRequestBindArray(const int _index, const T &_vals[]);
      bool           ResetSqlRequest(void) const;
      long           ExportSqlRequest(const string _file_name, const uint _flags,
                                      const string _separator);
      bool           SqlRequestRead(void);
      template<typename ST>
      bool           SqlRequestReadBind(ST &_s_object);
      void           FinalizeSqlRequest(void);
      long           PrintSqlRequest(const uint _flags=0) const;
      int            ColumnsCount(void) const;
      string         ColumnName(const int _col) const;
      ENUM_DATABASE_FIELD_TYPE ColumnType(const int _col) const;
      int            ColumnSize(const int _col) const;
      string         ColumnText(const int _col) const;
      int            ColumnInteger(const int _col) const;
      long           ColumnLong(const int _col) const;
      double         ColumnDouble(const int _col) const;
      template<typename T>
      bool           ColumnBlob(const int _col, T &_vals[]) const;
      //--- views
      bool           CreateView(const string _view_name, const string &_col_names[],
                                const bool _not_exists=true, const bool _is_temp=false);
      bool           CreateViewWhere(const string _view_name, const string &_col_names[],
                                     const string _where_cond,
                                     const bool _not_exists=true, const bool _is_temp=false
                                    );
      bool           DropView(const string _view_name, const bool _if_exists=true);
      bool           ListViews(CArrayString &_views_list, const bool _to_print=false);
   };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CDatabase::CDatabase(void) : m_name(NULL),
   m_handle(INVALID_HANDLE),
   m_flags(0),
   m_curr_table_name(NULL),
   m_sql_request_ha(INVALID_HANDLE),
   m_sql_request(NULL)
   {
   }
//+------------------------------------------------------------------+
//| Open                                                             |
//+------------------------------------------------------------------+
bool CDatabase::Open(const string _file_name, const uint _flags)
   {
   ::ResetLastError();
   m_handle = ::DatabaseOpen(_file_name, _flags);
   if(m_handle == INVALID_HANDLE)
      {
      ::PrintFormat(__FUNCTION__+": failed with code %d", ::GetLastError());
      return false;
      }
   m_name=_file_name;
   return true;
   }
//+------------------------------------------------------------------+
//| Close                                                            |
//+------------------------------------------------------------------+
void CDatabase::Close(void) const
   {
   ::DatabaseClose(m_handle);
   };
//+-------------------------------------------------------------------+
//| Start transaction execution                                       |
//+-------------------------------------------------------------------+
bool CDatabase::TransactionBegin(void)
   {
   return ::DatabaseTransactionBegin(m_handle);
   }
//+-------------------------------------------------------------------+
//| Complete transaction execution                                    |
//+-------------------------------------------------------------------+
bool CDatabase::TransactionCommit(void)
   {
   return ::DatabaseTransactionCommit(m_handle);
   }
//+-------------------------------------------------------------------+
//| Roll back transactions                                            |
//+-------------------------------------------------------------------+
bool CDatabase::TransactionRollback(void)
   {
   return ::DatabaseTransactionRollback(m_handle);
   }
//+------------------------------------------------------------------+
//| Query data                                                       |
//+------------------------------------------------------------------+
bool CDatabase::Select(const string _sql_request)
   {
   ::ResetLastError();
   if(!CreateSqlRequest(_sql_request))
      {
      ::PrintFormat(__FUNCTION__+": failed with code %d", ::GetLastError());
      return false;
      }
   if(!ExecuteSqlRequest())
      {
      ::PrintFormat(__FUNCTION__+": failed with code %d", ::GetLastError());
      return false;
      }
   return true;
   }
//+------------------------------------------------------------------+
//| Get a name                                                       |
//+------------------------------------------------------------------+
string CDatabase::Name(void) const
   {
   return m_name;
   }
//+------------------------------------------------------------------+
//| Get a handle                                                     |
//+------------------------------------------------------------------+
int CDatabase::Handle(void) const
   {
   return m_handle;
   }
//+------------------------------------------------------------------+
//| Get flags                                                        |
//+------------------------------------------------------------------+
uint CDatabase::Flags(void) const
   {
   return m_flags;
   }
//+------------------------------------------------------------------+
//| Get table names                                                  |
//+------------------------------------------------------------------+
CHashSet<string> *CDatabase::TableNames(void)
   {
   return ::GetPointer(m_table_names);
   }
//+------------------------------------------------------------------+
//| Get an SQL-request handle                                        |
//+------------------------------------------------------------------+
int CDatabase::SqlRequestHandle(void) const
   {
   return m_sql_request_ha;
   };
//+------------------------------------------------------------------+
//| Get an SQL-request                                               |
//+------------------------------------------------------------------+
string CDatabase::SqlRequest(void) const
   {
   return m_sql_request;
   };
//+------------------------------------------------------------------+
//| Find the structure                                               |
//+------------------------------------------------------------------+
bool CDatabase::Structure(const string _name, const bool _is_temp=false)
   {
   string sql_request=::StringFormat("SELECT sql FROM sqlite_schema WHERE name = '%s';", _name);
   if(_is_temp)
      sql_request=::StringFormat("SELECT sql FROM sqlite_temp_schema WHERE name = '%s';", _name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select a table                                                   |
//+------------------------------------------------------------------+
bool CDatabase::SelectTable(const string _table_name, const bool _is_temp=false)
   {
   m_curr_table_name=NULL;
//--- check a names array
   bool is_table_name, table_exists;
   is_table_name=m_table_names.Contains(_table_name);
   table_exists=true;
   if(_is_temp)
      {
      table_exists=is_table_name;
      }
   else
      {
      table_exists=TableExists(_table_name);
      }
   if(table_exists)
      {
      if(!is_table_name)
         m_table_names.Add(_table_name);
      m_curr_table_name=_table_name;
      }
   return m_curr_table_name!=NULL;
   }
//+------------------------------------------------------------------+
//| Create a new table                                               |
//+------------------------------------------------------------------+
bool CDatabase::CreateTable(const string _table_name, const string &_col_names[],
                            const bool _not_exists=true, const bool _is_temp=false)
   {
   if(DropTable(_table_name))
      {
      string temp_str, no_exist_str;
      temp_str=no_exist_str="";
      if(_is_temp)
         temp_str=" TEMP";
      if(_not_exists)
         no_exist_str=" IF NOT EXISTS";
      string sql_request=::StringFormat("CREATE%s TABLE%s %s(", temp_str,
                                        no_exist_str, _table_name);
      for(int idx=0; idx<::ArraySize(_col_names); idx++)
         sql_request+="\n"+_col_names[idx];
      sql_request+=");";
      if(!Select(sql_request))
         return false;
      ::ResetLastError();
      if(!m_table_names.Add(_table_name))
         {
         ::PrintFormat(__FUNCTION__+": failed to add a table, code %d", ::GetLastError());
         return false;
         }
      if(!SelectTable(_table_name, _is_temp))
         {
         ::Print(__FUNCTION__+": failed to select the table name");
         return false;
         }
      return true;
      }
   return false;
   }
//+------------------------------------------------------------------+
//| Create a new table as                                            |
//+------------------------------------------------------------------+
bool CDatabase::CreateTableAs(const string _table_name, const string _sql_request,
                              const bool _not_exists=true, const bool _is_temp=false)
   {
   if(DropTable(_table_name))
      {
      string temp_str, no_exist_str;
      temp_str=no_exist_str="";
      if(_is_temp)
         temp_str=" TEMP";
      if(_not_exists)
         no_exist_str=" IF NOT EXISTS";
      string sql_request=::StringFormat("CREATE%s TABLE%s %s AS \n%s", temp_str,
                                        no_exist_str, _table_name, _sql_request);
      if(!Select(sql_request))
         return false;
      ::ResetLastError();
      if(!m_table_names.Add(_table_name))
         {
         ::PrintFormat(__FUNCTION__+": failed to add a table, code %d", ::GetLastError());
         return false;
         }
      if(!SelectTable(_table_name, _is_temp))
         {
         ::Print(__FUNCTION__+": failed to select the table name");
         return false;
         }
      return true;
      }
   return false;
   }
//+------------------------------------------------------------------+
//| Drop the specified table                                         |
//+------------------------------------------------------------------+
bool CDatabase::DropTable(const string _table_name)
   {
//--- check if exists
   if(TableExists(_table_name))
      {
      string sql_request=::StringFormat("DROP TABLE %s", _table_name);
      if(!Select(sql_request))
         return false;
      }
//--- delete from a names array
   bool is_table_name=m_table_names.Contains(_table_name);
   if(is_table_name)
      {
      if(!m_table_names.Remove(_table_name))
         ::PrintFormat(__FUNCTION__+": failed to delete a table, code %d", ::GetLastError());
      }
   return true;
   }
//+------------------------------------------------------------------+
//| Drop the selected table                                          |
//+------------------------------------------------------------------+
bool CDatabase::DropCurrentTable(void)
   {
   return DropTable(m_curr_table_name);
   }
//+------------------------------------------------------------------+
//| Does a table exist?                                              |
//+------------------------------------------------------------------+
bool CDatabase::TableExists(const string _table_name)
   {
   return ::DatabaseTableExists(m_handle, _table_name);
   }
//+------------------------------------------------------------------+
//| Exports a table to a CSV file                                    |
//+------------------------------------------------------------------+
long CDatabase::ExportTable(const string _file_name, const uint _flags,
                            const string _separator)
   {
   return ::DatabaseExport(m_handle, m_curr_table_name, _file_name, _flags, _separator);
   }
//+------------------------------------------------------------------+
//| Import data from a file into a table                             |
//+------------------------------------------------------------------+
long CDatabase::ImportTable(const string _table_name, const string _file_name, const uint _flags,
                            const string _separator=";", const ulong _rows_to_skip=0,
                            const string  _skip_comments=NULL)
   {
   long imported=::DatabaseImport(m_handle, _table_name, _file_name, _flags, _separator,
                                  _rows_to_skip, _skip_comments);
   if(imported>0)
      SelectTable(_table_name);
   return imported;
   }
//+------------------------------------------------------------------+
//| Rename a table                                                   |
//+------------------------------------------------------------------+
bool CDatabase::RenameTable(const string _new_name)
   {
   string sql_request=::StringFormat("ALTER TABLE %s ", m_curr_table_name);
   sql_request+=::StringFormat("RENAME TO %s", _new_name);
   if(!Select(sql_request))
      return false;
   return true;
   }
//+------------------------------------------------------------------+
//| Insert a single row into the table                               |
//| Schema table:                                                    |
//|    INSERT INTO table (column1,column2 ,..)                       |
//|    VALUES( value1, value2 ,...);                                 |
//+------------------------------------------------------------------+
bool CDatabase::InsertSingleRow(const string &_col_names[], const string &_col_vals[])
   {
   uint names_num, vals_num;
   names_num =_col_names.Size();
   vals_num =_col_vals.Size();
   if(vals_num==names_num)
      {
      string insert_str=::StringFormat("INSERT INTO %s(", m_curr_table_name);
      string vals_str="\nVALUES(";
      for(uint c_idx=0; c_idx<names_num; c_idx++)
         {
         string curr_name=_col_names[c_idx];
         insert_str+=curr_name+",";
         string curr_val=_col_vals[c_idx];
         vals_str+=curr_val+",";
         }
      insert_str=::StringSubstr(insert_str, 0, ::StringLen(insert_str)-1); // delete the last comma
      insert_str+=")";
      vals_str=::StringSubstr(vals_str, 0, ::StringLen(vals_str)-1); // delete the last comma
      vals_str+=");";
      string sql_request=insert_str+vals_str;
      if(Select(sql_request))
         return true;
      }
   return false;
   }
//+------------------------------------------------------------------+
//| Insert a multiple rows into the table                            |
//| Schema table:                                                    |
//| INSERT INTO table1 (column1,column2 ,..)                         |
//|    VALUES                                                        |
//|    (value1,value2 ,...),                                         |
//|    (value1,value2 ,...),                                         |
//|    ...                                                           |
//|    (value1,value2 ,...);                                         |
//+------------------------------------------------------------------+
bool CDatabase::InsertMultipleRows(const string &_col_names[], const CArrayString &_rows_arr)
   {
   uint names_num, rows_num;
   names_num =_col_names.Size();
   string insert_str=::StringFormat("INSERT INTO %s(", m_curr_table_name);
   for(uint c_idx=0; c_idx<names_num; c_idx++)
      {
      string curr_name=_col_names[c_idx];
      insert_str+=curr_name+",";
      }
   insert_str=::StringSubstr(insert_str, 0, ::StringLen(insert_str)-1); // delete the last comma
   insert_str+=")";
   string vals_str="\nVALUES";
   ushort separator=',';
   rows_num =_rows_arr.Total();
   for(uint r_idx=0; r_idx<rows_num; r_idx++)
      {
      string curr_row_str=_rows_arr.At(r_idx);
      string split_result[];
      if(::StringSplit(curr_row_str, separator, split_result)!=names_num)
         return false;
      if(::StringLen(curr_row_str)>0)
         vals_str+="\n("+curr_row_str+"),";
      }
   vals_str=::StringSubstr(vals_str, 0, ::StringLen(vals_str)-1); // delete the last comma
   vals_str+=";";
   string sql_request=insert_str+vals_str;
   if(Select(sql_request))
      return true;
   return false;
   }
//+------------------------------------------------------------------+
//| Update existing data in a table                                  |
//| Schema table:                                                    |
//|    UPDATE table                                                  |
//|    SET column_1 = new_value_1,                                   |
//|        column_2 = new_value_2                                    |
//|    WHERE                                                         |
//|        search_condition;                                         |
//+------------------------------------------------------------------+
bool CDatabase::Update(const string &_col_names[], const string &_col_vals[],
                       const string _where_cond)
   {
   uint names_num, vals_num;
   names_num =_col_names.Size();
   vals_num =_col_vals.Size();
   if(vals_num==names_num)
      {
      string set_str="\nSET ";
      for(uint c_idx=0; c_idx<names_num; c_idx++)
         {
         string curr_name=_col_names[c_idx];
         string curr_val=_col_vals[c_idx];
         set_str+=curr_name+" = "+curr_val;
         set_str+=",";
         }
      set_str=::StringSubstr(set_str, 0, ::StringLen(set_str)-1); // delete the last comma
      //--- execute
      string sql_request=::StringFormat("UPDATE %s", m_curr_table_name)+set_str+
                         "\nWHERE "+"\n"+_where_cond;
      if(Select(sql_request))
         return true;
      }
   return false;
   }
//+------------------------------------------------------------------+
//| Empty a table                                                    |
//| Schema table:                                                    |
//|    DELETE FROM table;                                            |
//+------------------------------------------------------------------+
bool CDatabase::EmptyTable(void)
   {
   string sql_request=::StringFormat("DELETE FROM %s", m_curr_table_name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Delete existing data in a table                                  |
//| Schema table:                                                    |
//|    DELETE FROM table                                             |
//|    WHERE                                                         |
//|        search_condition;                                         |
//+------------------------------------------------------------------+
bool CDatabase::Delete(const string _where_cond)
   {
   string sql_request=::StringFormat("DELETE FROM %s", m_curr_table_name)+
                      "\nWHERE "+"\n"+_where_cond;
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Replace existing data in a table                                 |
//| Schema table:                                                    |
//|    REPLACE INTO table(column_list)                               |
//|    VALUES(value_list);                                           |
//+------------------------------------------------------------------+
bool CDatabase::Replace(const string &_col_names[], const string &_col_vals[])
   {
   uint names_num, vals_num;
   names_num =_col_names.Size();
   vals_num =_col_vals.Size();
   if(vals_num==names_num)
      {
      string replace_str=::StringFormat("REPLACE INTO %s(", m_curr_table_name);
      string vals_str="\nVALUES(";
      for(uint c_idx=0; c_idx<names_num; c_idx++)
         {
         string curr_name=_col_names[c_idx];
         replace_str+=curr_name+",";
         string curr_val=_col_vals[c_idx];
         vals_str+=curr_val+",";
         }
      replace_str=::StringSubstr(replace_str, 0, ::StringLen(replace_str)-1); // delete the last comma
      replace_str+=")";
      vals_str=::StringSubstr(vals_str, 0, ::StringLen(vals_str)-1); // delete the last comma
      vals_str+=");";
      string sql_request=replace_str+vals_str;
      if(Select(sql_request))
         return true;
      }
   return false;
   }
//+------------------------------------------------------------------+
//| Add a new column to a table                                      |
//+------------------------------------------------------------------+
bool CDatabase::AddColumn(const string &_col_definition)
   {
   string sql_request=::StringFormat("ALTER TABLE %s", m_curr_table_name);
   sql_request+=::StringFormat("\nADD COLUMN %s", _col_definition);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Rename a column of a table                                       |
//+------------------------------------------------------------------+
bool CDatabase::RenameColumn(const string _curr_name, const string _new_name)
   {
   string sql_request=::StringFormat("ALTER TABLE %s", m_curr_table_name);
   sql_request+=::StringFormat("\nRENAME COLUMN %s TO %s", _curr_name, _new_name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Print a table                                                    |
//+------------------------------------------------------------------+
long CDatabase::PrintTable(const uint _flags=0) const
   {
   return ::DatabasePrint(m_handle, m_curr_table_name, _flags);
   }
//+------------------------------------------------------------------+
//| Select from a table                                              |
//+------------------------------------------------------------------+
bool CDatabase::SelectFrom(const string &_col_names[])
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", m_curr_table_name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select from a table grouped by                                   |
//+------------------------------------------------------------------+
bool CDatabase::SelectFromGroupBy(const string &_col_names[], const string &_group_names[])
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", m_curr_table_name);
   sql_request+=" GROUP BY ";
   for(int o_idx=0; o_idx<::ArraySize(_group_names); o_idx++)
      sql_request+=_group_names[o_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select from a table ordered by                                   |
//+------------------------------------------------------------------+
bool CDatabase::SelectFromOrderedBy(const string &_col_names[], const string &_ord_names[])
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", m_curr_table_name);
   sql_request+=" ORDER BY ";
   for(int o_idx=0; o_idx<::ArraySize(_ord_names); o_idx++)
      sql_request+=_ord_names[o_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select distinct rows from a table                                |
//+------------------------------------------------------------------+
bool CDatabase::SelectDistinctFrom(const string &_col_names[])
   {
   string sql_request="SELECT DISTINCT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", m_curr_table_name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select distinct rows from a table ordered by                     |
//+------------------------------------------------------------------+
bool CDatabase::SelectDistinctFromOrderedBy(const string &_col_names[], const string &_ord_names[])
   {
   string sql_request="SELECT DISTINCT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", m_curr_table_name);
   sql_request+=" ORDER BY ";
   for(int o_idx=0; o_idx<::ArraySize(_ord_names); o_idx++)
      sql_request+=_ord_names[o_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select from a table on condition                                 |
//+------------------------------------------------------------------+
bool CDatabase::SelectFromWhere(const string &_col_names[], const string _where_cond)
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s WHERE %s", m_curr_table_name, _where_cond);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Select from a table on condition ordered by                      |
//+------------------------------------------------------------------+
bool CDatabase::SelectFromWhereOrderedBy(const string &_col_names[], const string _where_cond,
      const string &_ord_names[])
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s WHERE %s", m_curr_table_name, _where_cond);
   sql_request+=" ORDER BY ";
   for(int o_idx=0; o_idx<::ArraySize(_ord_names); o_idx++)
      sql_request+=_ord_names[o_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Inner join                                                       |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|        (table1.column1, table2.column2,..)                       |
//|    FROM table1                                                   |
//|    INNER JOIN table2                                             |
//|    ON join_condition;                                            |
//+------------------------------------------------------------------+
bool CDatabase::InnerJoin(const string &_col_names[], const string _other_table,
                          const string _join_cond)
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", _other_table);
   sql_request+=::StringFormat(" INNER JOIN %s ", m_curr_table_name);
   sql_request+=::StringFormat(" ON %s ", _join_cond);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Left join                                                        |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|        (table1.column1, table2.column2,..)                       |
//|    FROM table1                                                   |
//|    LEFT OUTER JOIN table2                                        |
//|    ON join_condition;                                            |
//+------------------------------------------------------------------+
bool CDatabase::LeftJoin(const string &_col_names[], const string _other_table,
                         const string _join_cond)
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", _other_table);
   sql_request+=::StringFormat(" LEFT JOIN %s", m_curr_table_name);
   sql_request+=::StringFormat(" ON %s ", _join_cond);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Cross join                                                       |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|        (column1,column2 ,..)                                     |
//|    FROM table1                                                   |
//|    CROSS JOIN table2;                                            |
//+------------------------------------------------------------------+
bool CDatabase::CrossJoin(const string &_col_names[], const string _other_table)
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", _other_table);
   sql_request+=::StringFormat(" CROSS JOIN %s ", m_curr_table_name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Self join                                                        |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|        (x.column_name, y.column_name..)                          |
//|    FROM table1 x, table1 y                                       |
//|    WHERE x.column_name1 = y.column_name1;                        |
//+------------------------------------------------------------------+
bool CDatabase::SelfJoin(const string &_col_names[], const string _from,
                         const string _where_cond)
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", _from);
   sql_request+=::StringFormat(" WHERE %s ", _where_cond);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Left join                                                        |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|        (table1.column1, table2.column2,..)                       |
//|    FROM table1                                                   |
//|    FULL OUTER JOIN table2                                        |
//|    ON join_condition;                                            |
//+------------------------------------------------------------------+
bool CDatabase::FullOuterJoin(const string &_col_names[], const string _other_table,
                              const string _join_cond)
   {
   string sql_request="SELECT ";
   for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat(" FROM %s", _other_table);
   sql_request+=::StringFormat(" FULL OUTER JOIN %s", m_curr_table_name);
   sql_request+=::StringFormat(" ON %s ", _join_cond);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Union                                                            |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|      (table1.column1, table1.column2,..)                         |
//|    FROM table1                                                   |
//|    WHERE search_condition1                                       |
//|    UNION [ALL]                                                   |
//|    SELECT                                                        |
//|      (table2.column1, table2.column2,..)                         |
//|    FROM table2                                                   |
//|    WHERE search_condition2;                                      |
//+------------------------------------------------------------------+
bool CDatabase::Union(const string &_col_names[], const string _where_cond1,
                      const string _other_table, const string &_other_col_names[],
                      const string _where_cond2, const bool _all=false)
   {
   uint col_size, other_col_size;
   col_size=_col_names.Size();
   other_col_size=_other_col_names.Size();
   if(col_size!=other_col_size)
      return false;
   string sql_request="SELECT ";
   for(uint n_idx=0; n_idx<col_size; n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat("\nFROM %s", m_curr_table_name);
   if(::StringLen(_where_cond1)>0)
      sql_request+="\nWHERE "+_where_cond1;
   string all_op_str="";
   if(_all)
      all_op_str="ALL";
   sql_request+=::StringFormat("\nUNION %s", all_op_str);
   sql_request+="\nSELECT ";
   for(uint n_idx=0; n_idx<other_col_size; n_idx++)
      sql_request+=_other_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat("\nFROM %s", _other_table);
   if(::StringLen(_where_cond1)>0)
      sql_request+="\nWHERE "+_where_cond2;
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Except                                                           |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|      (table1.column1, table1.column2,..)                         |
//|    FROM table1                                                   |
//|    EXCEPT                                                        |
//|    SELECT                                                        |
//|      (table2.column1, table2.column2,..)                         |
//|    FROM table2;                                                  |
//+------------------------------------------------------------------+
bool CDatabase::Except(const string &_col_names[], const string _other_table,
                       const string &_other_col_names[])
   {
   uint col_size, other_col_size;
   col_size=_col_names.Size();
   other_col_size=_other_col_names.Size();
   if(col_size!=other_col_size)
      return false;
   string sql_request="SELECT ";
   for(uint n_idx=0; n_idx<col_size; n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat("\nFROM %s", m_curr_table_name);
   sql_request+="\nEXCEPT";
   sql_request+="\nSELECT ";
   for(uint n_idx=0; n_idx<other_col_size; n_idx++)
      sql_request+=_other_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat("\nFROM %s", _other_table);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| Except                                                           |
//| Schema table:                                                    |
//|    SELECT                                                        |
//|      (table1.column1, table1.column2,..)                         |
//|    FROM table1                                                   |
//|    INTERSECT                                                     |
//|    SELECT                                                        |
//|      (table2.column1, table2.column2,..)                         |
//|    FROM table2;                                                  |
//+------------------------------------------------------------------+
bool CDatabase::Intersect(const string &_col_names[], const string _other_table,
                          const string &_other_col_names[])
   {
   uint col_size, other_col_size;
   col_size=_col_names.Size();
   other_col_size=_other_col_names.Size();
   if(col_size!=other_col_size)
      return false;
   string sql_request="SELECT ";
   for(uint n_idx=0; n_idx<col_size; n_idx++)
      sql_request+=_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat("\nFROM %s", m_curr_table_name);
   sql_request+="\nINTERSECT";
   sql_request+="\nSELECT ";
   for(uint n_idx=0; n_idx<other_col_size; n_idx++)
      sql_request+=_other_col_names[n_idx]+",";
   sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
   sql_request+=::StringFormat("\nFROM %s", _other_table);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| List all the tables                                              |
//+------------------------------------------------------------------+
bool CDatabase::ListTables(CArrayString &_tables_list, const bool _to_print=false)
   {
   if(!_tables_list.Shutdown())
      return false;
   string sql_request=
      "SELECT name FROM ( "
      "SELECT * FROM sqlite_schema "
      "UNION ALL "
      "SELECT * FROM sqlite_temp_schema) "
      "WHERE type ='table' AND name NOT LIKE 'sqlite_%'"
      "ORDER BY name;";
//--- real
   if(!Select(sql_request))
      return false;
   if(_to_print)
      ::PrintFormat("\nThe current DB \"%s\" includes such tables:", m_name);
   uint t_cnt=0;
   while(SqlRequestRead())
      {
      string curr_table_name=ColumnText(0);
      if(curr_table_name!=NULL)
         {
         _tables_list.Add(curr_table_name);
         if(_to_print)
            {
            ::PrintFormat("   Table #%d: %s", t_cnt+1, curr_table_name);
            t_cnt++;
            }
         }
      }
   FinalizeSqlRequest();
   return true;
   }
//+------------------------------------------------------------------+
//| Create a request                                                 |
//+------------------------------------------------------------------+
bool CDatabase::CreateSqlRequest(const string _sql_request)
   {
   m_sql_request_ha=::DatabasePrepare(m_handle, _sql_request);
   m_sql_request=_sql_request;
   return m_sql_request_ha!=INVALID_HANDLE;
   }
//+------------------------------------------------------------------+
//| Execute a request                                                |
//+------------------------------------------------------------------+
bool CDatabase::ExecuteSqlRequest(void)
   {
   return ::DatabaseExecute(m_handle, m_sql_request);
   }
//+------------------------------------------------------------------+
//| Set a parameter value                                            |
//+------------------------------------------------------------------+
template<typename T>
bool CDatabase::SqlRequestBind(const int _index, const T _val)
   {
   return ::DatabaseBind(m_sql_request_ha, _index, _val);
   }
//+------------------------------------------------------------------+
//| Set an array as a parameter value                                |
//+------------------------------------------------------------------+
template<typename T>
bool CDatabase::SqlRequestBindArray(const int _index, const T &_vals[])
   {
   return ::DatabaseBindArray(m_sql_request_ha, _index, _vals);
   }
//+------------------------------------------------------------------+
//| Reset a request                                                  |
//+------------------------------------------------------------------+
bool CDatabase::ResetSqlRequest(void) const
   {
   return ::DatabaseReset(m_sql_request_ha);
   }
//+------------------------------------------------------------------+
//| Exports an SQL request execution result to a CSV file            |
//+------------------------------------------------------------------+
long CDatabase::ExportSqlRequest(const string _file_name, const uint _flags,
                                 const string _separator)
   {
   return ::DatabaseExport(m_handle, m_sql_request, _file_name, _flags, _separator);
   }
//+------------------------------------------------------------------+
//| Move to the next entry                                           |
//+------------------------------------------------------------------+
bool CDatabase::SqlRequestRead(void)
   {
   return ::DatabaseRead(m_sql_request_ha);
   }
//+-------------------------------------------------------------------+
//| Moves to the next record and read data into the structure from it |
//+-------------------------------------------------------------------+
template<typename ST>
bool CDatabase::SqlRequestReadBind(ST &_s_object)
   {
   return ::DatabaseReadBind(m_sql_request_ha, _s_object);
   }
//+------------------------------------------------------------------+
//| Removes an sql request                                           |
//+------------------------------------------------------------------+
void CDatabase::FinalizeSqlRequest(void)
   {
   ::DatabaseFinalize(m_sql_request_ha);
   m_sql_request_ha=INVALID_HANDLE;
   }
//+------------------------------------------------------------------+
//| Print an SQL request                                             |
//+------------------------------------------------------------------+
long CDatabase::PrintSqlRequest(const uint _flags=0) const
   {
   return ::DatabasePrint(m_handle, m_sql_request, _flags);
   }
//+-------------------------------------------------------------------+
//| Get the number of fields in a request                             |
//+-------------------------------------------------------------------+
int CDatabase::ColumnsCount(void) const
   {
   return ::DatabaseColumnsCount(m_sql_request_ha);
   }
//+-------------------------------------------------------------------+
//| Get a field name by index                                         |
//+-------------------------------------------------------------------+
string CDatabase::ColumnName(const int _col) const
   {
   string col_name=NULL, temp_name;
   if(::DatabaseColumnName(m_sql_request_ha, _col, temp_name))
      col_name=temp_name;
   return col_name;
   }
//+-------------------------------------------------------------------+
//| Get a field type by index                                         |
//+-------------------------------------------------------------------+
ENUM_DATABASE_FIELD_TYPE CDatabase::ColumnType(const int _col) const
   {
   return ::DatabaseColumnType(m_sql_request_ha, _col);
   }
//+-------------------------------------------------------------------+
//| Get a field size in bytes                                         |
//+-------------------------------------------------------------------+
int CDatabase::ColumnSize(const int _col) const
   {
   return ::DatabaseColumnSize(m_sql_request_ha, _col);
   }
//+-------------------------------------------------------------------+
//| Get a field value as a string                                     |
//+-------------------------------------------------------------------+
string CDatabase::ColumnText(const int _col) const
   {
   string col_txt=NULL, temp_txt;
   if(::DatabaseColumnText(m_sql_request_ha, _col, temp_txt))
      col_txt=temp_txt;
   return col_txt;
   }
//+------------------------------------------------------------------+
//| Get the int type value                                           |
//+------------------------------------------------------------------+
int CDatabase::ColumnInteger(const int _col) const
   {
   int col_val=WRONG_VALUE, temp_val;
   if(::DatabaseColumnInteger(m_sql_request_ha, _col, temp_val))
      col_val = temp_val;
   return col_val;
   }
//+------------------------------------------------------------------+
//| Get the long type value                                          |
//+------------------------------------------------------------------+
long CDatabase::ColumnLong(const int _col) const
   {
   long col_val=WRONG_VALUE, temp_val;
   if(::DatabaseColumnLong(m_sql_request_ha, _col, temp_val))
      col_val = temp_val;
   return col_val;
   }
//+------------------------------------------------------------------+
//| Get the double type value                                        |
//+------------------------------------------------------------------+
double CDatabase::ColumnDouble(const int _col) const
   {
   double col_val=WRONG_VALUE, temp_val;
   if(::DatabaseColumnDouble(m_sql_request_ha, _col, temp_val))
      col_val = temp_val;
   return col_val;
   }
//+------------------------------------------------------------------+
//| Get a field value as an array                                    |
//+------------------------------------------------------------------+
template<typename T>
bool CDatabase::ColumnBlob(const int _col, T &_vals[]) const
   {
   return ::DatabaseColumnBlob(m_sql_request_ha, _col, _vals);
   }
//+---------------------------------------------------------------------+
//| Create view                                                         |
//| Schema table:                                                       |
//|    CREATE [TEMP] VIEW [IF NOT EXISTS] view_name AS                  |
//|    SELECT column1, column2.....                                     |
//|    FROM table_name;                                                 |
//+---------------------------------------------------------------------+
bool CDatabase::CreateView(const string _view_name, const string &_col_names[],
                           const bool _not_exists=true, const bool _is_temp=false)
   {
   if(DropView(_view_name))
      {
      string temp_str, no_exist_str;
      temp_str=no_exist_str="";
      if(_is_temp)
         temp_str=" TEMP";
      if(_not_exists)
         no_exist_str=" IF NOT EXISTS";
      string sql_request=::StringFormat("CREATE%s VIEW%s %s AS", temp_str,
                                        no_exist_str, _view_name);
      sql_request+="\nSELECT ";
      for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
         sql_request+="\n"+_col_names[n_idx]+",";
      sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
      sql_request+=::StringFormat("\nFROM %s", m_curr_table_name);
      return Select(sql_request);
      }
   return false;
   }
//+---------------------------------------------------------------------+
//| Create view                                                         |
//| Schema table:                                                       |
//|    CREATE [TEMP] VIEW [IF NOT EXISTS] view_name AS                  |
//|    SELECT column1, column2.....                                     |
//|    FROM table_name                                                  |
//|    WHERE [condition];                                               |
//+---------------------------------------------------------------------+
bool CDatabase::CreateViewWhere(const string _view_name, const string &_col_names[],
                                const string _where_cond,
                                const bool _not_exists=true, const bool _is_temp=false)
   {
   if(DropView(_view_name))
      {
      string temp_str, no_exist_str;
      temp_str=no_exist_str="";
      if(_is_temp)
         temp_str=" TEMP";
      if(_not_exists)
         no_exist_str=" IF NOT EXISTS";
      string sql_request=::StringFormat("CREATE%s VIEW%s %s AS", temp_str,
                                        no_exist_str, _view_name);
      sql_request+="\nSELECT ";
      for(int n_idx=0; n_idx<::ArraySize(_col_names); n_idx++)
         sql_request+="\n"+_col_names[n_idx]+",";
      sql_request=::StringSubstr(sql_request, 0, ::StringLen(sql_request)-1);
      sql_request+=::StringFormat("\nFROM %s", m_curr_table_name);
      sql_request+="\nWHERE "+_where_cond;
      return Select(sql_request);
      }
   return false;
   }
//+------------------------------------------------------------------+
//| Delete a view                                                    |
//+------------------------------------------------------------------+
bool CDatabase::DropView(const string _view_name, const bool _if_exists=true)
   {
   string exist_str="";
   if(_if_exists)
      exist_str=" IF EXISTS";
   string sql_request=::StringFormat("DROP VIEW%s %s", exist_str, _view_name);
   return Select(sql_request);
   }
//+------------------------------------------------------------------+
//| List all the views                                               |
//+------------------------------------------------------------------+
bool CDatabase::ListViews(CArrayString &_views_list, const bool _to_print=false)
   {
   if(!_views_list.Shutdown())
      return false;
   string sql_request=
      "SELECT name FROM ( "
      "SELECT * FROM sqlite_schema "
      "UNION ALL "
      "SELECT * FROM sqlite_temp_schema) "
      "WHERE type ='view'"
      "ORDER BY name;";
//--- real
   if(!Select(sql_request))
      return false;
   if(_to_print)
      ::PrintFormat("\nThe current DB \"%s\" includes such views:", m_name);
   uint v_cnt=0;
   while(SqlRequestRead())
      {
      string curr_view_name=ColumnText(0);
      if(curr_view_name!=NULL)
         {
         _views_list.Add(curr_view_name);
         if(_to_print)
            {
            ::PrintFormat("   View #%d: %s", v_cnt+1, curr_view_name);
            v_cnt++;
            }
         }
      }
   FinalizeSqlRequest();
   return true;
   }
//+------------------------------------------------------------------+
