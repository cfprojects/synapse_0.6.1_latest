<!---
	Name         	: SynapseClass.cfc
	Author       	: deebo
	Created      	: 4/20/2010 7:01:08 AM
	Last Updated 	: 4/20/2010 7:01:08 AM
	Purpose	 		: ORM class
	History      	: 8/7/2010 Deleted functions now handled by transient SynapseBean
					: 8/16/2010 added decorator feature
--->
<cfcomponent output="false">
	<cfproperty name="VARIABLES.dsn" default="">
	<cfproperty name="VARIABLES.table" default="">
	<cfproperty name="VARIABLES.alias" default="">
	<cfproperty name="VARIABLES.properties" default="">
	<cfproperty name="VARIABLES.pktype" default="auto-uuid" hint="option: manual,auto-uuid,auto-increment">
	<cfproperty name="VARIABLES.memlog" default="">
	<cfproperty name="VARIABLES.dsnDBType" default="">
	<cfproperty name="VARIABLES.children" default="">
	<cfproperty name="VARIABLES.parents" default="">
	<cfproperty name="VARIABLES.siblings" default="">
	<cfproperty name="VARIABLES.primarykeyname" default="">
	<cfproperty name="VARIABLES.defaultdisplayproperty" default="">
	<cfproperty name="VARIABLES.decorator" default="">
	<cfproperty name="VARIABLES.interceptor" default="">
	<cfproperty name="VARIABLES.lastpersistedat" default="">
	<cfproperty name="VARIABLES.usecache" default="false">
	
	<cffunction name="init" access="public" returntype="Any" output="false" hint="I initialize a class to a table">
		<cfargument name="dsn" required="true" type="String">
		<cfargument name="table" required="true" type="String" hint="I am the table that this object">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		
		<cfargument name="pktype" required="false" type="String">
		<cfargument name="usecache" required="false" type="Boolean" default="false">
		<cfargument name="memlog" required="false" type="Boolean" default="true">
		
		<cfset VARIABLES.dsn = ARGUMENTS.dsn>
		<cfset VARIABLES.table = ARGUMENTS.table>
		<cfset VARIABLES.alias = ARGUMENTS.alias>
		<cfset VARIABLES.properties = structNew()>
		<cfset VARIABLES.children = structNew()>
		<cfset VARIABLES.parents = structNew()>
		<cfset VARIABLES.siblings = structNew()>
		<cfset VARIABLES.primarykeyname = 'id'>
		<cfset VARIABLES.pktype = 'auto-uuid'>
		<cfset VARIABLES.memlog = ARGUMENTS.memlog>
		<cfset VARIABLES.usecache = ARGUMENTS.usecache>
		<cfset VARIABLES.decorator = ''>
		<cfset VARIABLES.interceptor = ''>
		<cfset VARIABLES.lastpersistedat = now()>
		
		
		<cfif structKeyExists(ARGUMENTS,'pktype')>
			<cfset VARIABLES.pktype = ARGUMENTS.pktype>
		</cfif>
		
		<!--- DETERMINE DB TYPE --->
		<cfset determineDBType()>
		<!--- GET COLUMNS FROM TABLE --->
		<cfdbinfo datasource="#this.getDSN()#" table="#this.getTable()#" name="columns" type="Columns">
		<cfloop query="columns">
			<cfset property = createObject('component','SynapseProperty').init(columns)>
			<cfset VARIABLES.properties[COLUMN_NAME] = property>
			<cfif IS_PRIMARYKEY>
				<cfset VARIABLES.primarykeyname = COLUMN_NAME>
			</cfif>
			<!--- <cfif COLUMN_DEFAULT_VALUE NEQ ''>
				<cfset evaluate("this.set#property.getName()#('#property.getDefaultValue()#')")>
				<!--- <cfset evaluate("this.set#COLUMN_NAME#('')")> --->
			<cfelse>
				<cfswitch expression="#columns.TYPE_NAME#">
					<cfcase value="datetime">
						<cfset evaluate("this.set#COLUMN_NAME#(now())")>
					</cfcase>
					<cfdefaultcase>
						<cfset evaluate("this.set#COLUMN_NAME#('')")>
					</cfdefaultcase>
				</cfswitch>
			</cfif> --->
			
		</cfloop>
		
		<cfset doLog('INIT #getAlias()#')>
		
		<cfreturn this>
	</cffunction>
		
	<cffunction name="generateID" access="package" returntype="Any" output="false" hint="I generate a id for a new record">
		<cfreturn createUUID()>
	</cffunction>
	
	<!--- ACCSESSORS AND MUTATORS (mostly private) --->
	<cffunction name="ignoreOnUpdate" access="public" returntype="void" output="false" hint="I set/override the properties to ignore on update">
		<cfargument name="property" required="false" type="String" hint="I am a property names to ignore on update">
		<cfargument name="ignore" required="false" default="true" type="Boolean" hint="I a boolean indicated">
			<cfset var LOCAL = structNew()>
			<cfset LOCAL.property = VARIABLES.properties[ARGUMENTS.property]>
			<cfset LOCAL.property.ignoreOnUpdate(ARGUMENTS.ignore)>
	</cffunction>
	
	<cffunction name="setDSN"  access="private" returntype="void" output="false" hint="I set/override the default dsn">
		<cfargument name="dsn" required="false" type="String" hint="I am the datasource name">
			<cfset VARIABLES.dsn = ARGUMENTS.dsn>
	</cffunction>
	
	<cffunction name="getDSN"  access="public" returntype="String" output="false" hint="I return the default datasource name">
		<cfreturn VARIABLES.dsn>
	</cffunction>
	
	<cffunction name="setTable"  access="private" returntype="void" output="false" hint="I set this classes table">
		<cfargument name="table" required="false" type="String">
			<cfset VARIABLES.table = ARGUMENTS.table>
	</cffunction>
	
	<cffunction name="getTable"  access="public" returntype="String" output="false" hint="I return the name of this classes table">
		<cfreturn VARIABLES.table>
	</cffunction>
	
	<cffunction name="setAlias"  access="private" returntype="void" output="false" hint="I set this classes alias">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
			<cfset VARIABLES.alias = ARGUMENTS.alias>
	</cffunction>
	
	<cffunction name="getAlias"  access="public" returntype="String" output="false" hint="I return this classes alias">
		<cfreturn VARIABLES.alias>
	</cffunction>
	
	<cffunction name="useCache" access="public" returntype="Boolean" output="false" hint="I set or return whether caching is used">
		<cfargument name="usecache" type="Boolean" required="false">
		
		<cfif structKeyExists(ARGUMENTS,'usecache')>
			<cfset VARIABLES.usecache = ARGUMENTS.usecache>
		</cfif>
		
		<cfreturn VARIABLES.useCache>
	</cffunction>
	
	<cffunction name="getProperties" access="public" returntype="Array" output="false" hint="I return a list of this classes properties/columns">
		<cfreturn structKeyArray(VARIABLES.properties)>
	</cffunction>
	
	<cffunction name="getPKType" access="public" returntype="String" output="false" hint="I return the primary key type (option: manual,auto-uuid)">
		<cfreturn VARIABLES.pktype>
	</cffunction>
	
	<cffunction name="getInterceptor" access="public" returntype="Any" output="false" hint="I return the primary key type (option: manual,auto-uuid)">
		<cfreturn VARIABLES.interceptor>
	</cffunction>
	
	<!--- RELATIONSHIPS --->
	<cffunction name="addChild" access="public" returntype="void" output="false" hint="I add a child relationship to this class">
		<cfargument name="class" type="Any" required="true" hint="The object of the child">
		<cfargument name="foreignkeyname" type="String" required="true" hint="Foreign key column name of [ARGUMENTS.class] child object">
		
		<cfset var LOCAL = structNew()>
		
		<!--- create link --->
		<cfset LOCAL.link = createObject("component","SynapseLink").init(ARGUMENTS.class,ARGUMENTS.foreignkeyname,'one-to-many')>
		<cfset LOCAL.alias = LOCAL.link.getAlias()>
		
		<!--- log changes --->
		<cfset doLog('ADD CHILD:#LOCAL.alias# to #getAlias()#')>
		<!--- add child relationship --->
		<cfset VARIABLES.children[LOCAL.alias] = LOCAL.link>
		
		<!--- set childs parent as this class --->
		<cfset VARIABLES.children[LOCAL.alias].getORMClass().addParent(this,ARGUMENTS.foreignkeyname)>
		
	</cffunction>
	
	<cffunction name="addSibling" access="public" returntype="void" output="false" hint="I add a sibling relationship to this class">
		<cfargument name="class" type="Any" required="true" hint="The object of the sibling">
		<cfargument name="linktable" type="String" required="true" hint="Name of linking table">
		<cfargument name="foreignkeyname" type="String" required="true" hint="Foreign key column name of [this] linking object">
		<cfargument name="linktoforeignkeyname" type="String" required="true" hint="Foreign key column name of [other] linking object">
		
		<cfset var LOCAL = structNew()>
		
		<!--- create link --->
		<cfset LOCAL.link = createObject("component","SynapseLink").init(ARGUMENTS.class,ARGUMENTS.foreignkeyname,'many-to-many',ARGUMENTS.linktable,ARGUMENTS.linktoforeignkeyname)>
		<cfset LOCAL.alias = LOCAL.link.getAlias()>
		
		<!--- log changes --->
		<cfset doLog('ADD SIBLING:#LOCAL.alias# to #getAlias()#')>
		
		<cfset VARIABLES.siblings[LOCAL.alias] = LOCAL.link>
		
		<!--- MAKE IT SO SIBLING RELATIONSHIP FLOWS BOTH WAYS --->
		<cfif NOT ARGUMENTS.class.hasSibling(getAlias())>
			<cfset ARGUMENTS.class.addSibling(this,ARGUMENTS.linktable,ARGUMENTS.linktoforeignkeyname,ARGUMENTS.foreignkeyname)>
		</cfif>
		
		
	</cffunction>
	
	<cffunction name="addParent" access="public" returntype="void" output="false" hint="I add a parent relationship to this class">
		<cfargument name="class" type="Any" required="true" hint="Object of the parent">
		<cfargument name="foreignkeyname" type="String" required="true" hint="Foreign key column name of [this] child object">
		
		<cfset var LOCAL = structNew()>
		
		<!--- create link --->
		<cfset LOCAL.link = createObject("component","SynapseLink").init(ARGUMENTS.class,ARGUMENTS.foreignkeyname,'many-to-one')>
		<cfset LOCAL.alias = LOCAL.link.getAlias()>
		
		<!--- log changes --->
		<cfset doLog('ADD PARENT:#LOCAL.alias# to #getAlias()#')>
		
		<cfset VARIABLES.parents[LOCAL.alias] = LOCAL.link>
		
	</cffunction>
	
	<!--- GET STRUCTS STORING RELATIONS --->
	<cffunction name="getChildren"  access="public" returntype="Struct" output="false" hint="I return a struct of children relationship links">
		<cfreturn VARIABLES.children>
	</cffunction>

	<cffunction name="getSiblings" access="public" returntype="Struct" output="false" hint="I return a struct of sibling(many-to-many) relationship links">
		<cfreturn VARIABLES.siblings>
	</cffunction>

	<cffunction name="getParents"  access="public" returntype="Struct" output="false" hint="I return a struct of parent relationship links">
		<cfreturn VARIABLES.parents>
	</cffunction>
	
	<cffunction name="getChildLink"  access="public" returntype="Any" output="false" hint="I return a struct of children relationship links">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		<cfreturn VARIABLES.children[ARGUMENTS.alias]>
	</cffunction>

	<cffunction name="getSiblingLink" access="public" returntype="Any" output="false" hint="I return a struct of sibling(many-to-many) relationship links">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		<cfreturn VARIABLES.siblings[ARGUMENTS.alias]>
	</cffunction>

	<cffunction name="getParentLink"  access="public" returntype="Any" output="false" hint="I return a struct of parent relationship links">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		<cfreturn VARIABLES.parents[ARGUMENTS.alias]>
	</cffunction>
	
	<!--- CRUD: NOW HANDLED IN SYNAPSE BEAN (8/7/2010 - 8 August 2010) --->

	<!--- MANIPULATION and DECISION --->

	<cffunction name="isPropertyRequired"  access="public" returntype="boolean" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.isNullable = VARIABLES.properties[ARGUMENTS.property].getIsNullable()>
		<cfset LOCAL.required = true>
		<cfif LOCAL.isNullable>
			<cfset LOCAL.required = false>
		</cfif>
		<cfreturn LOCAL.required>
	</cffunction>	
	
	<cffunction name="isPropertyParentKey"  access="public" returntype="boolean" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>

		<cfloop collection="#VARIABLES.parents#" item="l">
			<cfif VARIABLES.parents[l].getForeignKeyName() EQ trim(ARGUMENTS.property)>
				<cfset LOCAL.result = true>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="getPropertyParentAlias"  access="public" returntype="String" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = ''>

		<cfloop collection="#VARIABLES.parents#" item="l">
			<cfif VARIABLES.parents[l].getForeignKeyName() EQ trim(ARGUMENTS.property)>
				<cfset LOCAL.result = VARIABLES.parents[l].getAlias()>
				<cfbreak>
			</cfif>
		</cfloop>

		<cfreturn LOCAL.result>
	</cffunction>

	<cffunction name="hasSibling"  access="public" returntype="boolean" output="false" hint="I return whether the property is required">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		
		<cfif structKeyExists(ARGUMENTS,'alias')>
			<cfset LOCAL.result = structKeyExists(VARIABLES.siblings,'#ARGUMENTS.alias#')>
		<cfelseif structCount(VARIABLES.siblings) GT 0>
			<cfset LOCAL.result = true>
		</cfif>

		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="getPropertySiblingAlias"  access="public" returntype="String" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = ''>

		<cfloop collection="#VARIABLES.siblings#" item="l">
			<cfif VARIABLES.siblings[l].getForeignKeyName() EQ trim(ARGUMENTS.property)>
				<cfset LOCAL.result = VARIABLES.siblings[l].getAlias()>
				<cfbreak>
			</cfif>
		</cfloop>

		<cfreturn LOCAL.result>
	</cffunction>
	<!--- UTILITY --->
	<cffunction name="tsPersistence" access="package" returntype="void" output="false" hint="I set the date/time for this classes last persistence operation">
		<cfset VARIABLES.lastpersistedat = now()>
	</cffunction>
	
	<cffunction name="tsOfLastPersistence" access="public" returntype="Any" output="false" hint="I set the date/time for this classes last persistence operation">
		<cfreturn VARIABLES.lastpersistedat>
	</cffunction>
	
	<cffunction name="decorate" access="public" returntype="void" output="false" hint="I accept the decorator for the SynapseBean">
		<cfargument name="path" required="true" type="String" hint="I am the path to the object to use as a decorator">
		<cfset VARIABLES.decorator = createObject("component",ARGUMENTS.path)>
	</cffunction>
	
	<cffunction name="intercept" access="public" returntype="void" output="false" hint="I accept the Interceptor for the SynapseBean">
		<cfargument name="path" required="true" type="String" hint="I am the path to the object to use as an interceptor">
		<cfset VARIABLES.interceptor = createObject("component",ARGUMENTS.path)>
	</cffunction>
	
	<cffunction name="getBean" access="public" returntype="synapse.synapseBean" output="false" hint="I return a SynapseBean for this SynapseClass">
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.bean = createObject("component","synapse.SynapseBean").init(this)>
		
		<!--- DECORATOR --->
		<cfif NOT isSimpleValue(VARIABLES.decorator)>
			<cfset LOCAL.bean.decorate(VARIABLES.decorator)>
		</cfif>
		
		<!--- INTERCEPTOR --->
		<!--- <cfif NOT isSimpleValue(VARIABLES.interceptor)>
			<cfset LOCAL.bean.decorate(VARIABLES.interceptor)>
		<cfelse>
			<cfset LOCAL.bean.decorate(createObject("component","synapse.SynapseInterceptor"))>
		</cfif> --->
		<!--- <cfif NOT isSimpleValue(VARIABLES.interceptor)>
			<cfset LOCAL.bean.interceptor(VARIABLES.interceptor)
		<cfelse>
			<cfset LOCAL.bean.interceptor(createObject("component","synapse.SynapseIterator"))>
		</cfif> --->
		
		<cfreturn LOCAL.bean>
	</cffunction>
	
	<cffunction name="hasDecorator" access="public" returntype="Boolean" output="false" hint="I indicate whether class has a decorator">
		<cfset var result = false>
		
		<cfif isObject(VARIABLES.decorator)>
			<cfset result = true>
		</cfif>
		<cfreturn result>
	</cffunction>
	
	<cffunction name="hasInterceptor" access="public" returntype="Boolean" output="false" hint="I indicate whether class has an interceptor">
		<cfset var result = false>
		
		<cfif isObject(VARIABLES.interceptor)>
			<cfset result = true>
		</cfif>
		<cfreturn result>
	</cffunction>
	
	<cffunction name="setDefaultDisplayProperty" access="public" returntype="void" output="false" hint="I set this classes' default display property">
		<cfargument name="property" required="false" type="String" hint="I am the display property">
			<cfset VARIABLES.defaultdisplayproperty = ARGUMENTS.property>
	</cffunction>
	
	<cffunction name="getDefaultDisplayProperty"  access="public" returntype="String" output="false" hint="I return this classes alias">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = getPKName()>
		
		<cfif len(VARIABLES.defaultdisplayproperty)>
			<cfset LOCAL.result = VARIABLES.defaultdisplayproperty>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="getPKName"  access="public" returntype="String" output="false" hint="I return the name of this classes primary key">
		<!--- <cfthrow message="#VARIABLES.primarykeyname#"> --->
		<cfreturn VARIABLES.primarykeyname>
	</cffunction>
	
	<cffunction name="getPKValue"  access="public" returntype="String" output="false" hint="I return the value of this classes primary key">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.id = evaluate('this.get#getPKName()#()')>
		<cfreturn LOCAL.id>
	</cffunction>
	
	<cffunction name="getProperty" access="public" returntype="SynapseProperty" output="false" hint="I return the specified property">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property which is returned">
		<cfset var LOCAL = structNew()>
		<cfreturn VARIABLES.properties[ARGUMENTS.property]>
	</cffunction>
	
	<cffunction name="getPropertyType" access="public" returntype="String" output="false" hint="I return the type of the specified property">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the type is returned">
		
		<cfreturn this.getProperty(ARGUMENTS.property).getType()>
	</cffunction>
	
	<cffunction name="getQueryParamType" access="public" returntype="String" output="false" hint="I get the queryparam type for a specified property">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the query param type is returned">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.paramType = ''>
		<cfset LOCAL.type = getPropertyType(ARGUMENTS.property)>
		
		<cfswitch expression="#LOCAL.type#">
			<cfcase value="DATETIME">
				<cfset LOCAL.paramType = 'CF_SQL_VARCHAR'>
			</cfcase>
			
			<cfcase value="DATE">
				<cfset LOCAL.paramType = 'CF_SQL_DATE'>
			</cfcase>
			
			<cfcase value="BIT">
				<cfset LOCAL.paramType = 'CF_SQL_BIT'>
			</cfcase>
			
			<cfcase value="TINYINT,SMALLINT">
				<cfset LOCAL.paramType = 'CF_SQL_SMALLINT'>
			</cfcase>
			
			<cfcase value="INT,INTEGER,DOUBLE">
				<cfset LOCAL.paramType = 'CF_SQL_INTEGER'>
			</cfcase>
			
			<cfcase value="DECIMAL">
				<cfset LOCAL.paramType = 'CF_SQL_DECIMAL'>
			</cfcase>
			
			<cfcase value="FLOAT">
				<cfset LOCAL.paramType = 'CF_SQL_FLOAT'>
			</cfcase>
			
			<cfcase value="MONEY">
				<cfset LOCAL.paramType = 'CF_SQL_MONEY'>
			</cfcase>
			
			<cfcase value="VARCHAR,TEXT">
				<cfset LOCAL.paramType = 'CF_SQL_VARCHAR'>
			</cfcase>
			
			<cfdefaultcase>
				<cfset LOCAL.paramType = 'CF_SQL_VARCHAR'>
			</cfdefaultcase>
			
		</cfswitch>
		
		<cfreturn LOCAL.paramType>
	</cffunction>
	
	<cffunction name="determineDBType" access="public" returntype="String" output="false" hint="I return the DB type for this classes datasource name">
		
		<cfif NOT structKeyExists(VARIABLES,'dsnDBType')>
			<cfdbinfo datasource="#getDSN()#" type="Version" name="LOCAL.version">
			<!--- <cfthrow message="#LOCAL.version.DRIVER_NAME#"> --->
			<cfif findNoCase('MySQL',"#LOCAL.version.DRIVER_NAME#")>
				<cfset VARIABLES.dsnDBType = 'MySQL'>
			<cfelseif findNoCase('Microsoft SQL Server',"#LOCAL.version.DRIVER_NAME#") OR findNoCase('MS SQL Server',"#LOCAL.version.DRIVER_NAME#")>
				<cfset VARIABLES.dsnDBType = 'MSSQL'>
			</cfif>
		</cfif>
		<cfreturn VARIABLES.dsnDBType>
	</cffunction>
	
	<cffunction name="colWrapper"  access="package" returntype="String" output="false" hint="I return the DB type for this classes datasource name">
		<cfargument name="columnName" required="true" type="String" hint="I am the column name">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.columnName = ARGUMENTS.columnName>
		<cfif this.determineDBType() EQ 'MySQL'>
			<cfset LOCAL.columnName = '`#LOCAL.columnName#`'>
		<cfelseif this.determineDBType() EQ 'MSSQL'>
			<cfset LOCAL.columnName = '[#LOCAL.columnName#]'>
		</cfif>
		
		<cfreturn LOCAL.columnName>
	</cffunction>
	
	<cffunction name="isMemLogOn" access="public" output="false" returntype="Boolean">
		<cfreturn VARIABLES.memlog>
	</cffunction>
	
	<cffunction name="doLog" access="private" output="false" returntype="void">
		<cfargument name="label" required="false" default="none">
		
		<!--- log mem --->
		<cfif VARIABLES.memlog>
			<cfset logMemoryStatus('CLASS/#ARGUMENTS.label#')>
		</cfif>
		
	</cffunction>
	
	<cffunction name="logMemoryStatus" access="private" output="false" returntype="void">
		<cfargument name="label" required="false" default="none">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.filename = "#dateFormat(now(),'yyyy-mm-dd')#.txt">
		<cfset LOCAL.datetime = "#dateFormat(now(),'yyyy-mm-dd')# #timeFormat(now(),'medium')#">
		
		<cfset LOCAL.runTime = createObject("java","java.lang.Runtime").getRuntime()>

		<cfset LOCAL.freeMem = LOCAL.runtime.freememory()/>
		
		<cfset LOCAL.freeMem = int((LOCAL.freeMem/1024)/1024)/>
		
		<cfsavecontent variable="LOCAL.toFile">
			<cfoutput>#LOCAL.datetime#] Free: #LOCAL.freeMem# MB (#ARGUMENTS.label#)</cfoutput>
		</cfsavecontent>
		<cffile action="append" addnewline="true" file="/synapse/log/#LOCAL.filename#" output="#trim(LOCAL.toFile)#">
		
	</cffunction>
</cfcomponent>