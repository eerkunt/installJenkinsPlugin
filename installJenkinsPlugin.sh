#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    echo "USAGE: $0 [pluginlist]"
    exit 1
fi

pluginDir="/var/jenkins_home/plugins"
owner="jenkins.jenkins"

mkdir -p "/var/lib/jenkins/plugins"

# installPlugin - This function installs given plugin with it's dependencies.
#
# $1 - The name of the plugin
# $2 - Skip flag, for existing packages
#
# Returns none
installPlugin() {
    if [ -f "$pluginDir/${1}.hpi" ] || [ -f "$pluginDir/${1}.jpi" ]; then

        if [ "$2" == "skip" ]; then
            return 1
        fi

        echo "Skipping $1 since it is already installed."
        return 0
    else

        if [ -z "$1" ]; then
            return 0
        fi

        returnCode=$(curl -I -s "https://updates.jenkins-ci.org/latest/${1}.hpi" | head -n 1 | cut -d ' ' -f2)

        if [ "$returnCode" == "404" ]; then
            echo "ERROR: Can not find $1 plugin."
            return 1
        else
            if [ -n "$3" ]; then
                echo "Installing $1 dependency for $3 ..."
            else
                echo "Installing $1 plugin ..."
            fi

            curl --progress-bar -L --output "$pluginDir/${1}.hpi" "https://updates.jenkins-ci.org/latest/${1}.hpi"
            deps=($(unzip -p "$pluginDir/${1}.hpi" META-INF/MANIFEST.MF | tr -d '\r' | sed -e ':a;N;$!ba;s/\n //g' | \
                grep -e "^Plugin-Dependencies" | awk '{print $2}' | tr ',' '\n' | grep -v "resolution:=optional" | \
                cut -d ':' -f1 | tr '\n' ' '))

            if [ "${#deps[@]}" -gt 0 ]; then
                echo "Found ${#deps[@]} dependencies for $1."
            fi

            for plugin in "${deps[@]}"; do
                if [ -e "$pluginDir/$plugin.hpi" ]; then
                    echo "Dependency $plugin already installed."
                else
                    installPlugin "$plugin" "skip" "$1"
                fi
            done

          return 0
        fi
  fi
}

for plugin in "$@"
do
    installPlugin "$plugin"
done

chown "${owner}" $pluginDir -R

echo "Plugins and dependencies installed. Please DO NOT forget to restart Jenkins!"