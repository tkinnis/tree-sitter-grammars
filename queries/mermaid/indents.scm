; Indentation hints for mermaid diagrams

; Sequence diagram blocks increase indent
(sequence_stmt_loop) @indent.begin
(sequence_stmt_rect) @indent.begin
(sequence_stmt_opt) @indent.begin
(sequence_stmt_alt) @indent.begin
(sequence_stmt_par) @indent.begin

; Flowchart subgraphs
(flow_stmt_subgraph) @indent.begin

; State diagram composites
(state_composite_body) @indent.begin

; Class diagram blocks
(class_stmt_class) @indent.begin

; "end" keyword decreases indent
"end" @indent.dedent
