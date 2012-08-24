.PHONY=all clean install start test kill principals printenv envquiet wtf
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml
# config files that only need to be copied rather than modified-by-
# xsl-and-copied.
OTHER_CONFIGS=log4j.properties

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/tmp/hadoop-data
MASTER=`hostname -f | tr "[:upper:]" "[:lower:]"`
HADOOP_RUNTIME=$(HOME)/hadoop-runtime
ZOOKEEPER_HOME=$(HOME)/zookeeper
REALM=EXAMPLE.COM
KADMIN_LOCAL="ssh 172.16.153.3 'sudo kadmin.local'"
all: $(CONFIGS)

printenv:
	make -s -e envquiet

envquiet:
	echo "Hadoop Runtime directory:     $(HADOOP_RUNTIME)"
	echo "Zookeeper Runtime directory:  $(ZOOKEEPER_HOME)"
	echo "Master hostname:              $(MASTER)"
	echo "Tmp directory:                $(TMPDIR)"
	echo "Realm name:                   $(REALM)"

principals:
	export MASTER=$(MASTER); sh principals.sh $(MASTER)

install: clean all
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

kill: 
	-sh kill.sh

start: kill
	-rm -rf /tmp/logs
	cd $(HOME)/hadoop-runtime
	rm -rf $(TMPDIR)
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format
	$(HADOOP_RUNTIME)/bin/hdfs namenode &
	$(HADOOP_RUNTIME)/bin/hdfs datanode &
	$(HADOOP_RUNTIME)/bin/yarn resourcemanager &
	$(HADOOP_RUNTIME)/bin/yarn nodemanager &
	$(ZOOKEEPER_HOME)/bin/zkServer.sh start-foreground 

# modify HDFS permissions so that normal user can run jobs.
permissions:
	kinit -k -t services.keytab hdfs/$(MASTER)@$(REALM)
	$(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp
	$(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(MASTER):8020/

#print some diagnostics
debug:
	echo "MASTER:         " $(MASTER)
	echo "REALM:          " $(REALM)
	echo "HADOOP_RUNTIME: " $(HADOOP_RUNTIME)

test:
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.0.1.tm6.jar pi 5 5

wtf:
	echo $(MASTER)

clean:
	-rm $(CONFIGS)

core-site.xml: templates/core-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

hdfs-site.xml: templates/hdfs-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` \
	         --stringparam realm $(REALM) \
                 --stringparam tmpdir $(TMPDIR) rewrite-hosts.xsl $^  | xmllint --format - > $@

mapred-site.xml: templates/mapred-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` rewrite-hosts.xsl $^ | xmllint --format - > $@

yarn-site.xml: templates/yarn-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam realm $(REALM) \
	         --stringparam homedir `echo $$HOME` rewrite-hosts.xsl $^ | xmllint --format - > $@

