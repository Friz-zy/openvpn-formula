{% from "openvpn/map.jinja" import map with context %}

include:
    - openvpn.config

extend:
{% for type, names in salt['pillar.get']('openvpn', {}).iteritems() %}
{% if type == 'server' or type == 'client' %}
{% for name, config in names.iteritems() %}
{# hardening #}
{% if type == 'server' and config.pam_auth is defined and config.pam_auth == True %}
{% if config.plugins is defined %}
{% do config['plugins'].append(map.pam_module + ' openvpn') %}
{% else %}
{% do config['plugins'] = [map.pam_module + ' openvpn'] %}
{% endif %}
{% endif %}
{% do config.update({'cipher': 'AES-256-CBC-HMAC-SHA1'}) %}
{% do config.update({'tls-cipher': 'TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384'}) %}
{% do config.update({'auth': 'SHA512'}) %}
    openvpn_config_{{ type }}_{{ name }}:
      file.managed:
        - context:
            name: {{ name }}
            config: {{ config }}
            user: {{ map.user }}
            group: {{ map.group }}

{% endfor %}
{% endif %}
{% endfor %}
