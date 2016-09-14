# This is the main state file for configuring openvpn.

{% from "openvpn/map.jinja" import map with context %}

# Install openvpn packages
openvpn_pkgs:
  pkg.installed:
    - pkgs:
      {% for pkg in map.pkgs %}
      - {{pkg }}
      {% endfor %}

# Generate diffie hellman files
{% for dh in map.dh_files %}
openvpn_create_dh_{{ dh }}:
  cmd.run:
    - name: openssl dhparam -out {{ map.conf_dir }}/dh{{ dh }}.pem {{ dh }}
    - creates: {{ map.conf_dir }}/dh{{ dh }}.pem
{% endfor %}

# Enable ip forwarding
net.ipv4.ip_forward:
  sysctl.present:
    - value: 1

# Enable iptables postrouting
# more options: https://arashmilani.com/post?id=53
{%- if config.server_bridge is not defined %}
openvpn_iptables_postrouting:
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

# Ensure openvpn service is running and autostart is enabled
openvpn_service:
  service.running:
    - name: {{ map.service }}
    - enable: True
    - require:
      - pkg: openvpn_pkgs

