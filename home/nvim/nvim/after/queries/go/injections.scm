;; extends

(const_spec
  name: (identifier)
  value: (expression_list (raw_string_literal) @injection.content
   (#lua-match? @injection.content "^`[\n|\t| ]*\{.*\}[\n|\t| ]*`$")
   (#offset! @injection.content 0 1 0 -1)
   (#set! injection.include-children)
   (#set! injection.language "json")))

(short_var_declaration
    left: (expression_list (identifier))
    right: (expression_list (raw_string_literal) @injection.content)
  (#lua-match? @injection.content "^`[\n|\t| ]*\{.*\}[\n|\t| ]*`$")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "json"))

(var_spec
  name: (identifier)
  value: (expression_list (raw_string_literal) @injection.content
   (#lua-match? @injection.content "^`[\n|\t| ]*\{.*\}[\n|\t| ]*`$")
   (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
   (#set! injection.language "json")))


([
  (interpreted_string_literal)
  (raw_string_literal)
  ] @injection.content
 (#match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?")
 (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
(#set! injection.language "sql"))

([
  (interpreted_string_literal)
  (raw_string_literal)
 ] @injection.content
 ; (#contains? @injection.content "-- sql" "--sql" 
 ;    "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN" "DATABASE"
 ;    "FOREIGN KEY" "GROUP BY" "HAVING" "CREATE TABLE" "CREATE INDEX" "INSERT INTO"
 ;    "NOT NULL" "PRIMARY KEY" "UPDATE SET" "TRUNCATE TABLE" "LEFT JOIN" 
 ;    "add constraint" "alter table" "alter column" "database" 
 ;    "foreign key" "group by" "having" "create table" "create index" "insert into"
 ;    "not null" "primary key" "update set" "truncate table" "left join")
 (#match? @injection.content "(CREATE|DROP|ALTER|TRUNCATE).*(DATABASE|TABLE|COLUMN|INDEX)")
 (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
 (#set! injection.language "sql"))


