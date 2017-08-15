%define install_base /usr/lib/perfsonar/
%define config_base  /etc/perfsonar
%define doc_base     /usr/share/doc

%define script_agent perfsonar-meshconfig-agent
%define script_guiagent perfsonar-meshconfig-guiagent

%define relnum 1 

Name:			perfsonar-meshconfig
Version:		4.0.1
Release:		%{relnum}%{?dist}
Summary:		perfSONAR Mesh Configuration Agent
License:		Distributable, see LICENSE
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		perfsonar-meshconfig-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:		noarch

%description
A package that pulls in all the Mesh Configuration RPMs.

%package shared
Summary:		perfSONAR Mesh Configuration Shared Components
Group:			Applications/Communications
Requires:		perl
Requires:		perl(Config::General)
Requires:		perl(Data::Dumper)
Requires:		perl(Data::UUID)
Requires:		perl(Data::Validate::Domain)
Requires:		perl(Data::Validate::IP)
Requires:		perl(English)
Requires:		perl(Exporter)
Requires:		perl(File::Basename)
Requires:		perl(File::Path)
Requires:		perl(FindBin)
Requires:		perl(Getopt::Long)
Requires:		perl(HTTP::Response)
Requires:		perl(IO::File)
Requires:		perl(IO::Socket::SSL)
Requires:		perl(JSON)
Requires:		perl(Log::Log4perl)
Requires:		perl(Module::Load)
Requires:		perl(Moose)
Requires:		perl(Net::DNS)
Requires:		perl(Net::IP)
Requires:		perl(NetAddr::IP)
Requires:		perl(POSIX)
Requires:		perl(Params::Validate)
Requires:		perl(RPC::XML::Client)
Requires:		perl(Regexp::Common)
Requires:		perl(Storable)
Requires:		perl(Time::HiRes)
Requires:		perl(URI::Split)
Requires:		perl(base)
Requires:		perl(lib)
Requires:		perl(vars)
Requires:		perl(warnings)
Requires:		coreutils
%if 0%{?el7}
BuildRequires: systemd
%{?systemd_requires: %systemd_requires}
%else
Requires:		chkconfig
%endif
Requires:		shadow-utils
Requires:       libperfsonar-perl
Obsoletes:      perl-perfSONAR_PS-MeshConfig-Shared
Provides:       perl-perfSONAR_PS-MeshConfig-Shared

%description shared
This package is the set of library files shared RPMs by the perfSONAR Mesh
Configuration agents.

%package agent
Summary:		perfSONAR Mesh Configuration Agent
Group:			Applications/Communications
Requires:		perfsonar-meshconfig-shared = %{version}-%{release}
Requires(post):	perfsonar-meshconfig-shared = %{version}-%{release}
Requires:       libperfsonar-perl
Requires:       libperfsonar-toolkit-perl
Requires:       libperfsonar-pscheduler-perl
Requires:       perl(Linux::Inotify2)
Obsoletes:      perl-perfSONAR_PS-MeshConfig-Agent
Provides:       perl-perfSONAR_PS-MeshConfig-Agent
Obsoletes:      perfsonar-regulartesting
Provides:       perfsonar-regulartesting

%description agent
The perfSONAR Mesh Configuration Agent downloads a centralized JSON file
describing the tests to run, and uses it to generate appropriate configuration
for the various services.

%package jsonbuilder
Summary:		perfSONAR Mesh Configuration JSON Builder
Group:			Applications/Communications
Requires:		perfsonar-meshconfig-shared
Requires:		libperfsonar-sls-perl
Obsoletes:      perl-perfSONAR_PS-MeshConfig-JSONBuilder
Provides:       perl-perfSONAR_PS-MeshConfig-JSONBuilder
%description jsonbuilder
The perfSONAR Mesh Configuration JSON Builder is used to convert the Mesh
.conf file format into a properly formed JSON file for agents to consume.


%package guiagent
Summary:		perfSONAR Mesh Configuration GUI Agent
Group:			Applications/Communications
Requires:		perfsonar-meshconfig-shared = %{version}-%{release}
Requires(post):	perfsonar-meshconfig-shared = %{version}-%{release}
Requires:		maddash-server
Requires:       nagios-plugins-perfsonar
Requires:       libperfsonar-toolkit-perl
Requires:       perl(Mo)
Requires:       perl(YAML)
Obsoletes:      perl-perfSONAR_PS-MeshConfig-GUIAgent
Provides:       perl-perfSONAR_PS-MeshConfig-GUIAgent
%description guiagent
The perfSONAR Mesh Configuration Agent downloads a centralized JSON file
describing the tests a mesh is running, and generates a MaDDash configuration.

%pre shared
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfsonar-meshconfig-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install

mkdir -p %{buildroot}/etc/init.d

%if 0%{?el7}
install -D -m 0644 scripts/%{script_agent}.service %{buildroot}/%{_unitdir}/%{script_agent}.service
install -D -m 0644 scripts/%{script_guiagent}.service %{buildroot}/%{_unitdir}/%{script_guiagent}.service
%else
install -D -m 0755 scripts/%{script_agent} %{buildroot}/etc/init.d/%{script_agent}
install -D -m 0755 scripts/%{script_guiagent} %{buildroot}/etc/init.d/%{script_guiagent}
%endif
rm -rf %{buildroot}/%{install_base}/scripts/

install -D -m 0644 %{buildroot}/%{install_base}/doc/cron-lookup_hosts %{buildroot}/%{doc_base}/perfsonar-meshconfig-jsonbuilder/cron-lookup_hosts
install -D -m 0644 %{buildroot}/%{install_base}/doc/example.conf %{buildroot}/%{doc_base}/perfsonar-meshconfig-jsonbuilder/example.conf
install -D -m 0644 %{buildroot}/%{install_base}/doc/example.json %{buildroot}/%{doc_base}/perfsonar-meshconfig-jsonbuilder/example.json
rm -rf %{buildroot}/%{install_base}/doc

%clean
rm -rf %{buildroot}

%post shared
mkdir -p /var/lib/perfsonar/meshconfig
chown perfsonar:perfsonar /var/lib/perfsonar/meshconfig

mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

%post jsonbuilder
if [ "$1" = "1" ]; then
    # clean install, check for pre 3.5.1 files
    if [ -e "/opt/perfsonar_ps/mesh_config/etc/lookup_hosts.conf" ]; then
        mv %{config_base}/meshconfig-lookuphosts.conf %{config_base}/meshconfig-lookuphosts.conf.default
        mv /opt/perfsonar_ps/mesh_config/etc/lookup_hosts.conf %{config_base}/meshconfig-lookuphosts.conf
    fi
fi

%post agent
%if 0%{?el7}
%systemd_post %{script_agent}.service
if [ "$1" = "1" ]; then
    #if new install, then enable
    systemctl enable %{script_agent}.service
    systemctl start %{script_agent}.service
fi
%else
/sbin/chkconfig --add %{script_agent}
if [ "$1" = "1" ]; then
    # clean install, check for pre 3.5.1 files
    if [ -e "/opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf" ]; then
        mv %{config_base}/meshconfig-agent.conf %{config_base}/meshconfig-agent.conf.default
        mv /opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf %{config_base}/meshconfig-agent.conf
    fi
    #make sure it is started on install 
    /sbin/service perfsonar-meshconfig-agent start &>/dev/null || :
fi
if [ "$1" = "2" ]; then
    # 4.0 upgrade
    if [ -e "/etc/perfsonar/regulartesting.conf" ]; then
        mv %{config_base}/meshconfig-agent-tasks.conf %{config_base}/meshconfig-agent-tasks.conf.default
        mv /etc/perfsonar/regulartesting.conf %{config_base}/meshconfig-agent-tasks.conf
        #remove old summaries
        sed -i '/<summary>/,/<\/summary>/d' %{config_base}/meshconfig-agent-tasks.conf
        #make sure this gets started on its first update to version with agent
        /sbin/service perfsonar-meshconfig-agent restart &>/dev/null || :
    fi
fi
#update regular_testing.conf path
sed -i "s:/opt/perfsonar_ps/regular_testing/etc/regular_testing.conf:/etc/perfsonar/regulartesting.conf:g" %{config_base}/meshconfig-agent.conf

%endif

%post guiagent
%if 0%{?el7}
%systemd_post %{script_guiagent}.service
if [ "$1" = "1" ]; then
    #if new install, then enable
    systemctl enable %{script_guiagent}.service
    systemctl start %{script_guiagent}.service
fi
%else
/sbin/chkconfig --add %{script_guiagent}
if [ "$1" = "1" ]; then
    # clean install, check for pre 3.5.1 files
    if [ -e "/opt/perfsonar_ps/mesh_config/etc/gui_agent_configuration.conf" ]; then
        mv %{config_base}/meshconfig-guiagent.conf %{config_base}/meshconfig-guiagent.conf.default
        mv /opt/perfsonar_ps/mesh_config/etc/gui_agent_configuration.conf %{config_base}/meshconfig-guiagent.conf
        sed -i "s:/opt/perfsonar_ps/nagios/bin:/usr/lib/nagios/plugins:g" %{config_base}/meshconfig-guiagent.conf
    fi
    
    #Correct paths on x86_64 hosts
    if [ -d "/usr/lib64/nagios/plugins" ]; then
        sed -i "s:/usr/lib/nagios/plugins:/usr/lib64/nagios/plugins:g" %{config_base}/meshconfig-guiagent.conf
    fi
    
    #Fix graph URL
    sed -i "s:/serviceTest:/perfsonar-graphs:g" %{config_base}/meshconfig-guiagent.conf
fi
if [ "$1" = "2" ]; then
    #make sure this gets started on its first update to version with guiagent
    /sbin/service perfsonar-meshconfig-guagent start &>/dev/null || :
    #make sure maddash.yaml is indeed owned by maddash
    chown maddash:maddash /etc/maddash/maddash-server/maddash.yaml &>/dev/null || :
fi
#migrate to new graphs in 4.0
sed -i "s:graphWidget.cgi::g" %{config_base}/meshconfig-guiagent.conf
%endif

#make sure logs are setup properly
sed -i "s:/var/log/perfsonar/:/var/log/maddash/:g" %{config_base}/meshconfig-guiagent-logger.conf
unlink /var/log/perfsonar/meshconfig-guiagent.log &>/dev/null || :
ln -s /var/log/maddash/meshconfig-guiagent.log /var/log/perfsonar/meshconfig-guiagent.log &>/dev/null || :

%preun agent
%if 0%{?el7}
%systemd_preun %{script_agent}.service
%else
if [ "$1" = "0" ]; then
	# Totally removing the service
	/etc/init.d/%{script_agent} stop
	/sbin/chkconfig --del %{script_agent}
fi
%endif

%postun agent
%if 0%{?el7}
%systemd_postun_with_restart %{script_agent}.service
%else
if [ "$1" != "0" ]; then
	# An RPM upgrade
	/etc/init.d/%{script_agent} restart
fi
%endif

%preun guiagent
%if 0%{?el7}
%systemd_preun %{script_guiagent}.service
%else
if [ "$1" = "0" ]; then
	# Totally removing the service
	/etc/init.d/%{script_guiagent} stop
	/sbin/chkconfig --del %{script_guiagent}
fi
%endif

%postun guiagent
%if 0%{?el7}
%systemd_postun_with_restart %{script_guiagent}.service
%else
if [ "$1" != "0" ]; then
	# An RPM upgrade
	/etc/init.d/%{script_guiagent} restart
fi
%endif

%files shared
%defattr(0644,perfsonar,perfsonar,0755)
%{install_base}/lib/perfSONAR_PS/MeshConfig/Utils.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Config
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/Base.pm

%files jsonbuilder
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/build_json
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/validate_json
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/validate_configuration
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/lookup_hosts
%config(noreplace) %{config_base}/meshconfig-lookuphosts.conf
%doc %{doc_base}/perfsonar-meshconfig-jsonbuilder/example.conf
%doc %{doc_base}/perfsonar-meshconfig-jsonbuilder/example.json
%doc %{doc_base}/perfsonar-meshconfig-jsonbuilder/cron-lookup_hosts

%files agent
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{config_base}/meshconfig-agent.conf
%config(noreplace) %{config_base}/meshconfig-agent-logger.conf
%config(noreplace) %{config_base}/meshconfig-agent-tasks.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/perfsonar_meshconfig_agent
%{install_base}/lib/perfSONAR_PS/MeshConfig/Agent.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/perfSONARRegularTesting.pm
%if 0%{?el7}
%attr(0644,root,root) %{_unitdir}/%{script_agent}.service
%else
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{script_agent}
%endif


%files guiagent
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{config_base}/meshconfig-guiagent.conf
%config(noreplace) %{config_base}/meshconfig-guiagent-logger.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/perfsonar_meshconfig_guiagent
%{install_base}/lib/perfSONAR_PS/MeshConfig/GUIAgent.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/MaDDash.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/MaDDash/DefaultReports.pm
%if 0%{?el7}
%attr(0644,root,root) %{_unitdir}/%{script_guiagent}.service
%else
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{script_guiagent}
%endif

%changelog
* Thu Jun 19 2014 andy@es.net 3.4-5
- Support for regular testing and esmond MA added

* Wed Feb 20 2013 aaron@internet2.edu 3.3-3
- Provide an 'include' mechanism that allows meshes to include the contents of different JSON files

* Fri Feb 01 2013 aaron@internet2.edu 3.3-2
- Don't configure redudant tests (same source, same destination, same test parameters)
- Allow port numbers to be specified in addresses
- Fix a bug where the test ports weren't getting saved if defined at the top-level

* Fri Jan 11 2013 asides@es.net 3.3-1
- Bumped version and release for 3.3 Toolkit release

* Wed Dec 12 2012 aaron@internet2.edu 3.2.2-10
- Use the owamp test ports if it's configured by the Toolkit
- Fix a minor warning if 'address' isn't specified in generate_configuration

* Thu Nov 29 2012 aaron@internet2.edu 3.2.2-9
- Preserve CentralHost and traceroute collector variables if they aren't configured in the mesh(es)
- Fix for an issue where removed tests would leave a junk measurementset around

* Thu Nov 29 2012 aaron@internet2.edu 3.2.2-8
- Allow hosts to be defined at the mesh and organization level
- Fix for an issue when generating the JSON for disjoint tests
- Add support for new MaDDash options to display the description in place of IPs

* Mon Oct 08 2012 aaron@internet2.edu 3.2.2-7
- Fix for a bug where CONTACTADDR and NOAGENT weren't being preserved in non-mesh tests

* Fri Oct 05 2012 aaron@internet2.edu 3.2.2-6
- Cache the meshes the host is participating in, and only update if at least one of them changes
- Add support for an option to force each member of a pSB tests to run both the send side and the receive side

* Wed Oct 03 2012 aaron@internet2.edu 3.2.2-5
- Preserve tests that weren't configured by mesh(es)

* Wed Aug 30 2012 aaron@internet2.edu 3.2.2-4
- Documentation updates

* Tue Aug 07 2012 aaron@internet2.edu 3.2.2-3
- Allow for the agent to configure against multiple meshes

* Thu Aug 02 2012 aaron@internet2.edu 3.2.2-2
- Add a GUI agent

* Tue Jun 05 2012 aaron@internet2.edu 3.2.2-1
- Initial spec file created
