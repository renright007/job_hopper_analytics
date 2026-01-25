{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- set base_schema = target.schema -%}
  {%- if custom_schema_name is none -%}
    {{ base_schema }}
  {%- else -%}
    {{ base_schema ~ '_' ~ custom_schema_name }}
  {%- endif -%}
{%- endmacro %}