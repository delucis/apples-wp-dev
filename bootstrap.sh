#!/bin/bash

print_color () { tput sgr 0 1; tput bold; printf "$1"; tput sgr0; printf "\n"; }

load_plugin () {
  plugin="$1"
  print_color "Installing $plugin plugin..."
  if ! wp @v plugin is-installed $plugin; then
    echo "Downloading and installing $plugin WordPress plugin..."
    wp @v plugin install $plugin --activate
  elif [[ $(wp @v plugin get $plugin --field=status) = "inactive" ]]; then
    echo "$plugin WordPress plugin is already installed but inactive, activating..."
    wp @v plugin activate $plugin
  else
    echo "$plugin WordPress plugin is already installed & activated, skipping..."
  fi
}

load_theme () {
  theme="$1"
  version=""
  if [[ $2 ]]; then version="--version=$2"; fi
  print_color "Installing $theme WordPress theme..."
  if ! wp @v theme is-installed $theme; then
    wp @v theme install $theme $version && echo "$theme WordPress theme installed."
  else
    echo "$theme WordPress theme is already installed, skipping..."
  fi
}


# Check all required CLIs are available
dependencies=( wget wp git unzip )
for dependency in "${dependencies[@]}"; do
  command -v $dependency >/dev/null 2>&1 || { echo >&2 "‘$dependency’ command is required but it’s not installed. Aborting."; exit 1; }
done

# Should be executed after you have run `vagrant up`
if [ ! -d "wordpress" ]; then
  echo "Can’t find directory: wordpress. Have you run \"vagrant up\" yet?"
  exit 1
fi

# Parse command line option flags
CLONE_STYLE="ssh"
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--https)
    CLONE_STYLE="https"
    shift # past argument
    ;;
    -s|--ssh)
    CLONE_STYLE="ssh"
    shift # past argument
    ;;
    *)
    echo "Unrecognised option $key. Try --https or --ssh."
    ;;
  esac
  shift # past argument or value
done


####################################
# PLUGIN INSTALLATION & ACTIVATION #
####################################

# Advanced Custom Fields Pro
print_color "Installing Advanced Custom Fields Pro plugin..."
if [ ! -d "wordpress/wp-content/plugins/advanced-custom-fields-pro" ]; then
  wget -O wordpress/wp-content/plugins/acf-pro.zip "http://connect.advancedcustomfields.com/index.php?p=pro&a=download&k=b3JkZXJfaWQ9NjQzMTJ8dHlwZT1kZXZlbG9wZXJ8ZGF0ZT0yMDE1LTA5LTE2IDAzOjE4OjEy"
  if [[ -f "wordpress/wp-content/plugins/acf-pro.zip" ]]; then
    unzip wordpress/wp-content/plugins/acf-pro.zip -d wordpress/wp-content/plugins
    rm wordpress/wp-content/plugins/acf-pro.zip
  else
    echo "Can’t find file: wordpress/wp-content/plugins/acf-pro.zip. Fatal error…"
    exit 1
  fi
else
  echo "Advanced Custom Fields Pro has already been downloaded, skipping download..."
fi
wp @v plugin activate advanced-custom-fields-pro

# All in One SEO Pack
print_color "Installing All in One SEO Pack plugin..."
wp @v plugin install all-in-one-seo-pack --activate

# Google XML Sitemaps
print_color "Installing Google XML Sitemaps plugin..."
wp @v plugin install google-sitemap-generator --activate

# WordPress Importer
print_color "Installing WordPress Importer plugin..."
wp @v plugin install wordpress-importer --activate


###################################
# THEME INSTALLATION & ACTIVATION #
###################################

# Set remote URL
if [[ $CLONE_STYLE == "https" ]]; then
  THEME_REMOTE_URL="https://github.com/delucis/apples.git"
elif [[ $CLONE_STYLE == "ssh" ]]; then
  THEME_REMOTE_URL="git@github.com:delucis/apples.git"
else
  THEME_REMOTE_URL="git@github.com:delucis/apples.git"
fi

# Install Twenty Twelve theme
print_color "Installing Twenty Twelve WordPress theme..."
wp @v theme install twentytwelve --version=1.1.1

# Install & activate Apples theme
print_color "Installing and activating apples WordPress theme..."
git clone $THEME_REMOTE_URL wordpress/wp-content/themes/apples
if [ -d "wordpress/wp-content/themes/apples" ]; then
  wp @v theme activate apples
else
  echo "Can’t find directory: wordpress/wp-content/themes/apples. Fatal error…"
  exit 1
fi


#############################
# POPULATE DATABASE CONTENT #
#############################

# Clean default generated content
print_color "Deleting generic WordPress content..."
wp @v post delete 1 --force # Delete ‘Hello world!’ post
wp @v post delete 2 --force # Delete sample page
# Import exported XML from claraiannotta.com
print_color "Importing claraiannotta.com content..."
if [ -d "content" ]; then
  wp @v import ../content --authors=create
else
  echo "Can’t find directory: content. Fatal error…"
  exit 1
fi
