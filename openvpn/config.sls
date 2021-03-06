{% from "openvpn/map.jinja" import map with context %}

include:
    - openvpn

{% for type, names in salt['pillar.get']('openvpn', {}).iteritems() %}

{% if type == 'server' or type == 'client' %}
{% for name, config in names.iteritems() %}

{% if type == 'server' and config.pam_auth is defined and config.pam_auth == True %}
{% if config.plugins is defined %}
{% do config['plugins'].append(map.pam_module + ' openvpn') %}
{% else %}
{% do config.update({'plugins': [map.pam_module + ' openvpn']}) %}
{% endif %}
{% endif %}

# Deploy {{ type }} {{ name }} config files
openvpn_config_{{ type }}_{{ name }}:
  file.managed:
    {%- if type == 'server' %}
    - name: {{ map.conf_dir }}/{{name}}.conf
    {%- elif type == 'client' %}
    - name: {{ map.conf_dir }}/{{name}}.ovpn
    {%- endif %}
    - source: salt://openvpn/files/{{ type }}.jinja
    - template: jinja
    - context:
        name: {{ name }}
        config: {{ config }}
        user: {{ map.user }}
        group: {{ map.group }}
    - watch_in:
      - service: openvpn_service

# Enable iptables postrouting
# more options: https://arashmilani.com/post?id=53
{%- if config.server_bridge is not defined %}
openvpn_iptables_postrouting_{{ type }}_{{ name }}:
  iptables.append:
    - table: nat
    - chain: POSTROUTING
    - jump: MASQUERADE
    - out-interface: eth0
{%- if config.server is defined %}
    - source: {{ config.server.split()[0] }}/24
{%- else %}
    - source: 10.8.0.0/24
{%- endif %}
{%- endif %}

{% if config.ca is defined and config.ca_content is defined %}
# Deploy {{ type }} {{ name }} CA file
openvpn_config_{{ type }}_{{ name }}_ca_file:
  file.managed:
    - name: {{ config.ca }}
    - contents_pillar: openvpn:{{ type }}:{{ name }}:ca_content
    - makedirs: True
    - watch_in:
      - service: openvpn_service
{% endif %}

{% if config.cert is defined and config.cert_content is defined %}
# Deploy {{ type }} {{ name }} certificate file
openvpn_config_{{ type }}_{{ name }}_cert_file:
  file.managed:
    - name: {{ config.cert }}
    - contents_pillar: openvpn:{{ type }}:{{ name }}:cert_content
    - makedirs: True
    - watch_in:
      - service: openvpn_service
{% endif %}

{% if config.key is defined and config.key_content is defined %}
# Deploy {{ type }} {{ name }} private key file
openvpn_config_{{ type }}_{{ name }}_key_file:
  file.managed:
    - name: {{ config.key }}
    - contents_pillar: openvpn:{{ type }}:{{ name }}:key_content
    - makedirs: True
    - mode: 600 
    - watch_in:
      - service: openvpn_service
{% endif %}

{% if config.tls_auth is defined and config.ta_content is defined %}
# Deploy {{ type }} {{ name }} TLS key file
openvpn_config_{{ type }}_{{ name }}_tls_auth_file:
  file.managed:
    - name: {{ config.tls_auth.split()[0] }}
    - contents_pillar: openvpn:{{ type }}:{{ name }}:ta_content
    - makedirs: True
    - mode: 600 
    - watch_in:
      - service: openvpn_service
{% endif %}

{% if config.status is defined %}
# Ensure status file exists and is writeable
openvpn_{{ type }}_{{ name }}_status_file:
  file.managed:
    - name: {{ config.status }}
    - makedirs: True
{% endif %}

{% if config.log is defined %}
# Ensure log file exists and is writeable
openvpn_{{ type }}_{{ name }}_log_file:
  file.managed:
    - name: {{ config.log }}
    - makedirs: True
{% endif %}

{% if config.log_append is defined %}
# Ensure log file exists and is writeable
openvpn_{{ type }}_{{ name }}_log_file_append:
  file.managed:
    - name: {{ config.log_append }}
    - makedirs: True
{% endif %}

{% if type == 'server' and config.pam_auth is defined and config.pam_auth == True %}
pam_server_{{ name }}:
  file.managed:
    - name: /etc/pam.d/openvpn
    - source: salt://openvpn/files/openvpn.pam
{% endif %}

{% if config.client_config_dir is defined %}
# Ensure client config dir exists
openvpn_config_{{ type }}_{{ name }}_client_config_dir:
  file.directory:
    - name: {{ map.conf_dir }}/{{ config.client_config_dir}}
    - makedirs: True

{% for client, client_config in salt['pillar.get']('openvpn:'+type+':'+name+':client_config', {}).iteritems() %}
# Client config for {{ client }}
openvpn_config_{{ type }}_{{ name }}_{{ client }}_client_config:
  file.managed:
    - name: {{ map.conf_dir }}/{{ config.client_config_dir}}/{{ client }}
    - contents_pillar: openvpn:{{ type }}:{{ name }}:client_config:{{ client }}
    - makedirs: True
{% endfor %}
{% endif %}

{% endfor %}
{% endif %}
{% endfor %}



