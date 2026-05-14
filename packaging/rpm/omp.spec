# RPM spec for omp CLI binary.
# The omp binary is fully standalone (Bun compiled binary with embedded
# Rust native addon). No shared library dependencies beyond glibc.

%global debug_package %{nil}
%global __os_install_post %{nil}
%global _build_id_links none

Name:           omp
Version:        %{_version}
Release:        0.%{_buildnum}.git%{_shortsha}%{?dist}
Summary:        AI coding agent for the terminal

License:        MIT
URL:            https://github.com/%{_owner}/oh-my-pi
ExclusiveArch:  x86_64 aarch64

Source0:        omp
Source1:        LICENSE

%description
Coding agent CLI with read, bash, edit, write tools and session management.
Fork of badlogic/pi-mono.

%prep

%build

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/omp
install -D -m 0644 %{SOURCE1} %{buildroot}%{_defaultlicensedir}/%{name}/LICENSE

%files
%license %{_defaultlicensedir}/%{name}/LICENSE
%{_bindir}/omp

%changelog
* %{_changelog_date} Can Boluk - %{version}-%{release}
- Automated build from commit %{_shortsha}