#!/usr/bin/env bash
# Shared image-build wiring for Dell XPS 13 9350 non-camera policies.

purplefin_configure_dell_xps_9350_common() {
	local battery_service="purplefin-dell-xps-9350-battery.service"
	local panel_service="purplefin-dell-xps-9350-panel.service"
	local panel_wants="/etc/systemd/user/graphical-session.target.wants/${panel_service}"
	local tuned_ppd_conf="/etc/tuned/ppd.conf"
	local tuned_profile="purplefin-dell-xps-9350-performance"
	local tuned_profile_conf="/usr/lib/tuned/profiles/${tuned_profile}/tuned.conf"
	local tuned_ppd_tmp command expected_setting

	for command in busctl gdctl gdbus gsettings glib-compile-schemas systemd-hwdb upower; do
		command -v "${command}" >/dev/null 2>&1 || {
			echo "Dell XPS 13 9350 policy requires ${command}" >&2
			exit 1
		}
	done
	test -f /usr/lib/systemd/system/upower.service

	chmod 0755 /usr/libexec/purplefin/configure-dell-xps-9350-battery
	chmod 0755 /usr/libexec/purplefin/dell-xps-9350-panel-policy

	echo ":: Configuring Dell XPS 9350 battery policy"
	systemd-hwdb --strict update
	systemd-hwdb query 'battery:BAT0:DELL TR7FC488:dmi:bvnDellInc.:svnDellInc.:pnXPS139350:' |
		grep -qx 'CHARGE_LIMIT=75,80'
	systemctl enable "${battery_service}"

	echo ":: Configuring Dell XPS 9350 laptop-safe Performance profile"
	test -f "${tuned_ppd_conf}"
	test -f "${tuned_profile_conf}"
	for expected_setting in \
		'include=balanced' \
		'energy_performance_preference=performance' \
		'boost=1' \
		'platform_profile=performance'; do
		grep -qxF "${expected_setting}" "${tuned_profile_conf}"
	done
	! grep -Eq '^[[:space:]]*(min_perf_pct|\[vm([^]]*)?\]|\[disk\])[[:space:]]*(=|$)' "${tuned_profile_conf}"
	tuned_ppd_tmp="$(mktemp)"
	awk -v profile="${tuned_profile}" '
		/^\[profiles\]$/ {
			in_profiles = 1
			print
			next
		}
		/^\[/ {
			in_profiles = 0
		}
		in_profiles && /^[[:space:]]*performance[[:space:]]*=/ {
			print "performance=" profile
			replaced = 1
			next
		}
		{ print }
		END { if (!replaced) exit 1 }
	' "${tuned_ppd_conf}" >"${tuned_ppd_tmp}"
	install -m 0644 "${tuned_ppd_tmp}" "${tuned_ppd_conf}"
	rm -f "${tuned_ppd_tmp}"
	grep -qx "performance=${tuned_profile}" "${tuned_ppd_conf}"

	echo ":: Configuring Dell XPS 9350 panel and ambient-brightness policy"
	test -L "${panel_wants}"
	test "$(readlink "${panel_wants}")" = '../../../../usr/lib/systemd/user/purplefin-dell-xps-9350-panel.service'
	glib-compile-schemas --strict /usr/share/glib-2.0/schemas
	GSETTINGS_BACKEND=memory gsettings get \
		org.gnome.settings-daemon.plugins.power ambient-enabled | grep -qx true
}
