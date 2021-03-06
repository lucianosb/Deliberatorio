#!/bin/bash

#   Deliberatório - Script para gerar os dados para carta do jogo
#   Copyright (C) 2013 Valessio Brito <contato@valessiobrito.com.br>
#                      Luciano Santa Brígida <lucianosb@sbvirtual.com.br>
#
#   Este arquivo é parte do programa Deliberatório. O Deliberatório é um
#   software livre; você pode redistribuí-lo e/ou modificá-lo dentro dos termos
#   da GNU General Public License como publicada pela Fundação do Software Livre
#   (FSF); na versão 3 da Licença. Este programa é distribuído na esperança que
#   possa ser útil, mas SEM NENHUMA GARANTIA; sem uma garantia implícita de
#   ADEQUAÇÃO a qualquer MERCADO ou APLICAÇÃO EM PARTICULAR. Veja a licença para
#   maiores detalhes. Você deve ter recebido uma cópia da GNU General Public License,
#   sob o título "LICENCA.txt", junto com este programa, se não, acesse
#   http://www.gnu.org/licenses/
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   Version 0.3 

# Definição do template para os cards
CARD_TEMPLATE="cards_padrao"
CARD_CARDDEP="$PWD/templates/$CARD_TEMPLATE/dep.svg"
CARD_EVENTS="$PWD/templates/$CARD_TEMPLATE/event.svg"
CARD_CARDORG="$PWD/templates/$CARD_TEMPLATE/org.svg"
CARD_PAUTAS="$PWD/templates/$CARD_TEMPLATE/prop.svg"

# Arquivos CSV gerados
CSV_DEPUTADOS="$PWD/all-dep.csv"
CSV_ORGAOS="$PWD/all-org.csv"
CSV_EVENTS="$PWD/event.csv"
CSV_PAUTAS="$PWD/prop.csv"
CSV_CARDDEP="$PWD/dep.csv"
CSV_CARDORG="$PWD/org.csv"

# Fontes dos WebService
URL_ORGAOS="http://www.camara.gov.br/SitCamaraWS/Orgaos.asmx/ObterOrgaos"
URL_DEPUTADOS="http://www.camara.gov.br/SitCamaraWS/Deputados.asmx/ObterDeputados"

# Arquivos TMPs ou Cache
TMP_PAUTAS=$( mktemp )
TMP_DEPUTADOS="$PWD/data/ObterDeputados.xml"
TMP_ORGAOS="$PWD/data/ObterOrgaos.xml"

# Criando diretórios do cache "data"
mkdir -p $PWD/data

# Verifica se existe o arquivo na cache
if [ ! -f $TMP_ORGAOS ]
then
    wget $URL_ORGAOS -O $TMP_ORGAOS 2> /dev/null
fi

if [ ! -f $TMP_DEPUTADOS ]
then
    wget $URL_DEPUTADOS -O $TMP_DEPUTADOS 2> /dev/null
fi

# Barra de Progresso
COUNT=0

function progresso {
   TOTAL=$1
   ProgBar="[=======================================================================]"
   ProgCount=$(( $COUNT * 73 / $TOTAL ))
   printf "\r%3d.%1d%% %.${ProgCount}s" $(( $COUNT * 100 / $TOTAL )) $(( ($COUNT * 1000 / $TOTAL) % 10 )) $ProgBar
}

# Questiona ao usuário se deve gerar novos dados
echo "Gerar nova base de Órgãos? [S]im ou [N]ão"
rm -i $CSV_ORGAOS 2> /dev/null
if [ -f $CSV_ORGAOS ]
then
   echo "Mantido a relação de Orgãos"
else
    echo "

   Obtendo Órgãos:"
   for idOrgao in `xmlstarlet sel -t -v "//orgaos/orgao/@id" $TMP_ORGAOS` ; do
      let COUNT++

      progresso $(xmlstarlet sel -t -v "//orgaos/orgao/@id" $TMP_ORGAOS | wc -l)

      # Parse no XML da sigla e descrição do Orgão
      siglaOrgao=$(xmlstarlet sel -t -v "//orgaos/orgao[$COUNT]/@sigla" $TMP_ORGAOS)
      descricaoOrgao=$(xmlstarlet sel -t -v "//orgaos/orgao[$COUNT]/@descricao" $TMP_ORGAOS)

      # Plotando no CSV dos Orgãos
      echo $idOrgao\;$siglaOrgao\;$descricaoOrgao >> $CSV_ORGAOS

   done
      echo "
      Relação de Orgãos atualizado.
      "
fi

echo "Atualizar a Pauta da Semana? [S]im ou [N]ão"
rm -i $CSV_PAUTAS 2> /dev/null
if [ -f $CSV_PAUTAS ]
then
   echo "Mantido a versão atual da Pauta."
else
   COUNT=0
   echo "Enter para continuar com a data atual, ou digite C e enter para customizar a data."
   read inputDate
    if [ $inputDate = "C" ]; then
        echo "Digite a data inicial (dd/mm/yyyy): "
        read datIni
        echo "Digite o intervalo da data final (dd/mm/yyy): "
        read datFim
    else
        datIni=$(date +%d\/%m\/%Y)
        datFim=$(date +%d\/%m\/%Y -d "+6 days")
   fi

   echo "

   Obtendo Pauta da Semana:"
   for idOrgao in `cat $CSV_ORGAOS | cut -d";" -f1`; do
   # OBTER PAUTAS
   URL_PAUTAS="http://www.camara.gov.br/SitCamaraWS/Orgaos.asmx/ObterPauta?IDOrgao=$idOrgao&datIni=$datIni&datFim=$datFim"
   wget $URL_PAUTAS -O $TMP_PAUTAS 2> /dev/null
   let COUNT++
   siglaOrgao=$(grep $idOrgao $CSV_ORGAOS | cut -d";" -f2)
   # Progresso da Pauta
   progresso $(cat $CSV_ORGAOS| wc -l)

   # Obter detalhes da Pauta
   PautaCOUNT=0
   for idPauta in `xmlstarlet sel -t -v "//pauta/reuniao/proposicoes/proposicao/sigla" $TMP_PAUTAS | sed s/\ /_/g` ; do
      let PautaCOUNT++
      ementaPauta=$(xmlstarlet sel -t -v "//pauta/reuniao/proposicoes/proposicao[$PautaCOUNT]/ementa" $TMP_PAUTAS)
      pontoPauta=$(echo $idPauta | rev | cut -c -2 | rev)
      nomePauta=$(echo $idPauta | sed s/"\/"/":"/g)
      echo $pontoPauta\;$(echo $idPauta | sed s/_/\ /g)\;$(echo $siglaOrgao | head -1 | cut -d" " -f1)\;$ementaPauta\;$nomePauta \
      | grep -E 'PL_|PEC_' \
      | grep -vE '(Altera|§|nova redação|revoga|Acrescenta|REQ_)'
   done | sort -R | head -3 >> $CSV_PAUTAS
   done #idOrgao
   echo "

    Obtenção das pautas, finalizado.

   "
fi

# OBTER DEPUTADOS
COUNT=0

echo "Gerar novos dados dos Deputados? [S]im ou [N]ão"
rm -i $CSV_DEPUTADOS 2> /dev/null

if [ -f $CSV_DEPUTADOS ]
then
   echo "Dados dos Deputados mantido."
else
   echo "

   Obtendo Deputados:"
   idDeputados=`xmlstarlet sel -t -v "//deputados/deputado/ideCadastro" $TMP_DEPUTADOS`

   for ideCadastro in $idDeputados ; do
      let COUNT++

      # Progresso dos Deputados
      progresso 513

      # Parser XML dos detalhes do Deputado
      nomeParlamentar=$(xmlstarlet sel -t -v "//deputados/deputado[$COUNT]/nomeParlamentar" $TMP_DEPUTADOS)
      partidoDeputado=$(xmlstarlet sel -t -v "//deputados/deputado[$COUNT]/partido" $TMP_DEPUTADOS)
      ufDeputado=$(xmlstarlet sel -t -v "//deputados/deputado[$COUNT]/uf" $TMP_DEPUTADOS)
      urlFoto=$(xmlstarlet sel -t -v "//deputados/deputado[$COUNT]/urlFoto" $TMP_DEPUTADOS)
      sexoDep=$(xmlstarlet sel -t -v "/deputados/deputado[$COUNT]/sexo" $TMP_DEPUTADOS)

      # Capturando detalhe do deputado no orgão
      URL_DETALHE="http://www.camara.gov.br/SitCamaraWS/Deputados.asmx/ObterDetalhesDeputado?ideCadastro=$ideCadastro&numLegislatura="
      TMP_DETALHE="$PWD/data/$ideCadastro.xml"
      if [ ! -f $TMP_DETALHE ]
      then
        wget $URL_DETALHE -O $TMP_DETALHE 2> /dev/null
      fi

      siglaDeputado=$(xmlstarlet sel -t -v "//Deputados/Deputado/comissoes/comissao[last()]/siglaComissao" $TMP_DETALHE | uniq)

      # Gerando CSV dos Deputados
      echo $ideCadastro\;$nomeParlamentar\;$partidoDeputado\;$ufDeputado\;$siglaDeputado\;$(echo $urlFoto | cut -d"/" -f7)\;$sexoDep >> $CSV_DEPUTADOS

   done

   echo "

Deputados obtidos com sucesso.

   "
fi

echo "Gerar nova base para os cartões? [S]im ou [N]ão"
rm -i $CSV_CARDDEP 2> /dev/null
if [ -f $CSV_CARDDEP ]
then
   echo "Base de cartões mantido."
else
   # Gera CSV de Orgaos e Deputados na Pauta
   listOrgPauta=`cat $CSV_PAUTAS | cut -d";" -f 3| sort | uniq`

   for cardOrgao in $listOrgPauta; do
      grep $cardOrgao $CSV_ORGAOS
   done | sort | uniq > $TMP_PAUTAS
   grep -v Especial $TMP_PAUTAS > $CSV_CARDORG

   # Filtra lista de deputados em orgãos na pauta
   listOrgDep=`cat $CSV_CARDORG | cut -d";" -f 2| sort | uniq`

   for cardOrgao in $listOrgDep; do
      grep $cardOrgao $CSV_DEPUTADOS | sort -R | head -4
   done  | sort | uniq > $CSV_CARDDEP

   echo "Nova base de cartões gerada."
fi

echo "Gerar cartões em PDF? [S]im ou [N]ão"
rm -ir $PWD/gerado 2> /dev/null
if [ -d gerado ]
then
   echo "Cartões em PDF anteriores mantido."
else

mkdir -p $PWD/gerado

CARDS="EVENTS PAUTAS CARDDEP CARDORG"

for cardItem in $CARDS; do
echo "

Gerando cards $cardItem em PDF
"
    eval CARD_FILE=$(echo \$CSV_$cardItem)
    eval CARD_TEMPLATE=$(echo \$CARD_$cardItem)
    COUNT=0
    for lineItem in `seq 1 $(cat $CARD_FILE | wc -l)`; do
        let COUNT++
        progresso $(cat $CARD_FILE | wc -l)
        LINE_ITEM=$(tail -$lineItem $CARD_FILE | head -1)
        FILE_ITEM="$PWD/gerado/$(echo $cardItem)_$lineItem"
        cat $CARD_TEMPLATE > $(echo $FILE_ITEM).svg
        for columItem in `seq 1 $(echo $LINE_ITEM | sed s/";"/"\n"/g | wc -l)` ; do
            sed -i -e "s#%VAR_$columItem%#$(echo $LINE_ITEM | cut -d';' -f$columItem)#g" $(echo $FILE_ITEM).svg
        done
        inkscape -z $(echo $FILE_ITEM).svg -A $(echo $FILE_ITEM).pdf 2> /dev/null > /dev/null
    done
done

fi

echo "

Compilando as cartas para impressão em modo 9xA4 e 16xA4
"
inkscape -z $PWD/instrucoes.svg -A $PWD/instrucoes.pdf 2> /dev/null > /dev/null

DESC=$(echo "Gerado $(wc -l $CSV_PAUTAS | sed s/prop.csv/Proposições/g) em $(wc -l $CSV_CARDORG | sed s/org.csv/Comissões/g) com $(wc -l $CSV_CARDDEP | sed s/dep.csv/Deputados/g) envolvidos nas discussões.
" | sed s%$PWD%%g)
AUTORES="BRÍGIDA, Luciano S. BRITO, Valessio S."
TERMOS="jogo, cartas, politica, câmara deputados"

pdfjoin --paper a4paper --frame true --pdftitle "Deliberatório - $(date +%d/%m/%Y)" --pdfauthor "$AUTORES" --pdfsubject "$(echo $DESC)" --pdfkeywords "$TERMOS" --nup 3x3 $PWD/gerado/*.pdf -o $PWD/cards_9xA4.pdf 2> /dev/null
pdfjoin $PWD/instrucoes.pdf $PWD/cards_9xA4.pdf -o Deliberatorio_9xA4_$(date +%d%m%Y).pdf 2> /dev/null > /dev/null
pdfjoin --paper a4paper --frame true --pdftitle "Deliberatório - $(date +%d/%m/%Y)" --pdfauthor "$AUTORES" --pdfsubject "$(echo $DESC)" --pdfkeywords "$TERMOS" --nup 4x4 $PWD/gerado/*.pdf -o $PWD/cards_16xA4.pdf 2> /dev/null
pdfjoin $PWD/instrucoes.pdf $PWD/cards_9xA4.pdf -o Deliberatorio_16xA4_$(date +%d%m%Y).pdf 2> /dev/null > /dev/null
rm instrucoes.pdf cards_9xA4.pdf cards_16xA4.pdf 2> /dev/null > /dev/null

echo "$DESC

Finalizado.
"
