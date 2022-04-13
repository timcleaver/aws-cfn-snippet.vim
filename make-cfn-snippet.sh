#!/usr/bin/env bash

set -e
set -u
set -o pipefail

export LC_ALL=C

function usage() {
  cat <<EOF
Usage: ./$0 [Option]

Option:
  -u,--ultisnip     format for UltiSnip.
  -n,--neosnippet    (default) format for NeoSnippet.
  -h,--help         display this message.
EOF
}

# option for below snippet plugins
# - neosnippet
# - Ultisnip
target="${1:-n}"
style=neosnippet
case "${target#-}" in
    n|-neosnippet)
        endsnippet_str=""
        style=neosnippet
        ;;
    u|-ultisnip)
        endsnippet_str="endsnippet"
        style=ultisnips
        ;;
    h|--help)
        usage
        exit 1
        ;;
    *)
        usage
        exit 1
        ;;
esac


# initialize variables
home=$(cd $(dirname $0); pwd)
aws_cfn_doc_repo="${home}/aws-cloudformation-user-guide"
aws_cfn_doc_dir="${aws_cfn_doc_repo}/doc_source"

# update submodule(aws-cloudformation-user-guide)
git submodule foreach git pull origin main
mkdir -p "${home}/snippets/"
rm -vrf "${home}"/snippets/*
mkdir -p "${home}/UltiSnips/"
rm -vrf "${home}"/UltiSnips/*

# main
cd "${aws_cfn_doc_dir}"
if [ "${style}" == neosnippet ]
then
    for file_type in yaml json
    do
      snip="${home}/snippets/${file_type}.snip"
      # AWS Resource snippets
      echo "### AWS Resource snippets" >> "${snip}"
      for FILE in $(grep "^### ${file_type^^}" aws-resource* | awk -F: '{ print $1 }' | sort -u)
      do
        echo "snippet $(sed -n 1P $FILE | sed -e 's/^# //g' -e 's/<a .*//g' -e 's/ /::/g')" >> "${snip}"

        start=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==1 { print $1}')" + 1)
        end=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==2 { print $1}')" - 1)

        sed -ne "/^### ${file_type^^}/,\$p" "$FILE" \
          | sed -ne "${start},${end}p" \
          | sed -e "s/^/  /g" \
          | sed -e "s/([^)]*)//g" \
          | sed -e "s/\[//g" -e "s/\]//g" >> "${snip}"
        echo -n "${endsnippet_str}" >> "${snip}"
        echo "" >> "${snip}"
        echo "" >> "${snip}"
      done

      # Resource Properties snippets
      echo "### Resource Properties snippets" >> "${snip}"
      for FILE in $(grep "^### ${file_type^^}" aws-properties-* | awk -F: '{ print $1 }' | sort -u)
      do
        echo -n "snippet $(sed -n 1P $FILE | sed -e 's/^# //g' -e 's/<a .*//g' -e 's/.* //g')" >> "${snip}"
        echo "$FILE" | sed -e 's/aws-properties//g' -e 's/.md//g' >> "${snip}"

        start=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==1 { print $1}')" + 1)
        end=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==2 { print $1}')" - 1)

        sed -ne "/^### ${file_type^^}/,\$p" "$FILE" \
          | sed -ne "${start},${end}p" \
          | sed -e "s/^/  /g" \
          | sed -e "s/([^)]*)//g" \
          | sed -e "s/\[//g" -e "s/\]//g" >> "${snip}"
        echo -n "${endsnippet_str}" >> "${snip}"
        echo "" >> "${snip}"
        echo "" >> "${snip}"
      done
    done

    cat >> "${home}/snippets/yaml.snip" <<-EOS
        snippet AWSTemplateFormatVersion
          AWSTemplateFormatVersion: "2010-09-09"
          Description: A sample template
          Resources:
              MyEC2Instance: # inline comment
                Type: "AWS::EC2::Instance"
                ...
        ${endsnippet_str}

    EOS
    exit
fi

# TODO: I don't use JSON CloudFormation with Ultisnips so I don't handle it here
snip="${home}/UltiSnips/cloudformation.snippets"
# AWS Resource snippets
echo "### AWS Resource snippets" >> "${snip}"
echo "extends yaml" >> "${snip}"
for FILE in $(grep "^### ${file_type^^}" aws-resource* | awk -F: '{ print $1 }' | sort -u)
do
    echo "snippet $(sed -n 1P $FILE | sed -e 's/^# //g' -e 's/<a .*//g' -e 's/ /::/g')" >> "${snip}"

    start=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==1 { print $1}')" + 1)
    end=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==2 { print $1}')" - 1)

    sed -ne "/^### ${file_type^^}/,\$p" "$FILE" \
      | sed -ne "${start},${end}p" \
      | sed -e "s/^/  /g" \
      | sed -e "s/([^)]*)//g" \
      | sed -e "s/\[//g" -e "s/\]//g" \
      | awk -F ':' 'BEGIN { i=1; } /snippet/ { i=1; } /[A-Za-z]+: [A-Za-z]+$/ { printf("%s: ${%d:", $1, i); gsub(" ", "", $2); printf("%s}\n", tolower($2)); i++; next } { print $0 }' >> "${snip}"
    echo -n "${endsnippet_str}" >> "${snip}"
    echo "" >> "${snip}"
    echo "" >> "${snip}"
done

# Resource Properties snippets
echo "### Resource Properties snippets" >> "${snip}"
for FILE in $(grep "^### ${file_type^^}" aws-properties-* | awk -F: '{ print $1 }' | sort -u)
do
    echo -n "snippet $(sed -n 1P $FILE | sed -e 's/^# //g' -e 's/<a .*//g' -e 's/.* //g')" >> "${snip}"
    echo "$FILE" | sed -e 's/aws-properties//g' -e 's/.md//g' >> "${snip}"

    start=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==1 { print $1}')" + 1)
    end=$(expr "$(sed -ne '/^### '${file_type^^}'/,$p' $FILE | grep -n '```' | awk -F: 'NR==2 { print $1}')" - 1)

    # TODO: the last awk should be conditional on whether it is ultisnips
    sed -ne "/^### ${file_type^^}/,\$p" "$FILE" \
      | sed -ne "${start},${end}p" \
      | sed -e "s/^/  /g" \
      | sed -e "s/([^)]*)//g" \
      | sed -e "s/\[//g" -e "s/\]//g" \
      | awk -F ':' 'BEGIN { i=1; } /snippet/ { i=1; } /[A-Za-z]+: [A-Za-z]+$/ { printf("%s: ${%d:", $1, i); gsub(" ", "", $2); printf("%s}\n", tolower($2)); i++; next } { print $0 }' >> "${snip}"
    echo -n "${endsnippet_str}" >> "${snip}"
    echo "" >> "${snip}"
    echo "" >> "${snip}"
done

cat >> "${home}/UltiSnips/cloudformation.snippets" <<-EOS
    snippet AWSTemplateFormatVersion
      AWSTemplateFormatVersion: "2010-09-09"
      Description: \${1:description}
      Metadata: \${2:metadata}
      Parameters: \${3:parameters}
      Mappings: \${3:mappings}
      Conditions: \${4:conditions}
      Transform: \${5:transform}
      Resources: \${6:resources}
      Outputs: ${7:outputs}
    ${endsnippet_str}

    snippet Parameter
    \${1:name}:
        Type: \${2:type}
        Default: \${3:default}
        Description: \${4:description}
    ${endnippet_str}

    snippet Output
    \${1:name}:
        Description: \${2:description}
        Value: \${3:value}
        Export:
            Name: \${4:export}
    ${endnippet_str}

EOS
