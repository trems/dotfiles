;; extends

((string_content) @injection.content
  (#any-match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?")
  (#set! injection.language "sql")
  (#set! injection.include-children))

(
 (macro_invocation
   (scoped_identifier
     path: (identifier) @_path (#eq? @_path "sqlx")
  )
   (token_tree
     (string_literal)) @injection.content
   )
  (#any-match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?")
  (#set! injection.language "sql")
  (#set! injection.include-children)
  (#offset! @injection.content 0 1 0 -1)
  )
  
  
