<!---
	Name         	: SynapseFactory.cfc
	Author       	: deebo
	Created      	: 4/20/2010 7:01:08 AM
	Last Updated 	: 4/20/2010 7:01:08 AM
	Purpose	 		: Factory for handling the ORM classes
	History      	: 8/7/2010 Changed new to return type SynapseBean instead of SynapseClass
					: 8/16/2010 added decorator feature
					: 8/17/2010 added paging functionality to list* methods
--->
<cfcomponent output="false">
	<cfproperty name="VARIABLES.dsn" default="">
	<cfproperty name="VARIABLES.classMap" default="">
	
	<cffunction name="init" access="public" returntype="Any" output="false" hint="I initialize the ORM Factory">
		<cfargument name="dsn" required="true" type="String" hint="I am the default datasource if you don't specify a datasource in other functions">
		<cfargument name="memlog" required="false" type="Boolean" default="false">
		<cfargument name="usecache" required="false" type="Boolean" default="false">
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset VARIABLES.dsn = ARGUMENTS.dsn>
		<cfelse>	
			<!--- <cfset VARIABLES.dsn = ""> --->
		</cfif>
		
		<cfset checkDSN()>
		
		<cfset VARIABLES.memlog = ARGUMENTS.memlog>
		<cfset VARIABLES.useCache = ARGUMENTS.useCache>
		
		<cfset VARIABLES.classMap = structNew()>
		<cfset doLog('========== INIT #getDSN()# ==========')>
		
		<cfset setup()>
		
		<cfreturn this>
	</cffunction>
	
	<cffunction name="setup" returntype="void" access="private">
	
	</cffunction>
	
	<cffunction name="log" returntype="void" access="public">
		<cfargument name="memlog" required="true" type="Boolean" default="false">
		
		<cfset VARIABLES.memlog = ARGUMENTS.memlog>
	</cffunction>
	
	<cffunction name="useCache" returntype="void" access="public">
		<cfargument name="usecache" required="true" type="Boolean" default="false">
		
		<cfset VARIABLES.useCache = ARGUMENTS.useCache>
	</cffunction>
	
	<!--- ENTITY --->
	<cffunction name="add" access="public" returntype="Any" output="false" hint="I add a persistence class that represents a table in the supplied datasource">
		<cfargument name="table" required="true" type="String" hint="I am the table to be represented in the factory as a class">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		<cfargument name="dsn" required="false" type="String" hint="I am the datasource to link to the table, factory default used if not supplied">
		<cfargument name="pktype" required="false" type="String" hint="I am an option describing the Primary Key type: manual,auto,auto-uuid">
		
		<cfset checkDSN()>
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.table = "">
		<cfset LOCAL.alias = "">
		<cfset LOCAL.dsn = "">
		<cfset LOCAL.class = "">
		<cfset LOCAL.pktype = "auto-uuid">
		
		<!--- DEFAULTS --->
		<cfset LOCAL.dsn = "">
		<cfset LOCAL.table = ARGUMENTS.table>
		
		<cfif structKeyExists(ARGUMENTS,'pktype')>
			<cfset LOCAL.pktype = ARGUMENTS.pktype>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'alias')>
			<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfelse>
			<cfset LOCAL.alias = LOCAL.table>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- CHECK THAT A DSN IS SET --->
		<cfif len(LOCAL.dsn) LT 1>
			<cfthrow message="No DSN specified. Please specify a default in init() or when adding a class.">
		</cfif>
		
		<!--- log changes --->
		<cfset doLog('ADD CLASS:#LOCAL.alias#')>
		
		<!--- create class --->
		<cfset LOCAL.class = createObject("component","synapse.SynapseClass").init(dsn=LOCAL.dsn,table=LOCAL.table,alias=LOCAL.alias,pktype=LOCAL.pktype,usecache=VARIABLES.usecache,memlog=VARIABLES.memlog)>
		
		<!--- add it to the class struct --->
		<cfset VARIABLES.classMap[LOCAL.alias] = LOCAL.class>
		
		<!--- return newly created class --->
		<cfreturn VARIABLES.classMap[LOCAL.alias]>
	</cffunction>
	
	<cffunction name="remove" access="public" returntype="Boolean" output="false" hint="I remove a persistence class that represents a table in the supplied datasource">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.result = false>
		
		<cfif structKeyExists(VARIABLES.classMap,ARGUMENTS.alias)>
			<cfset structDelete(VARIABLES.classMap,ARGUMENTS.alias)>
			<cfset LOCAL.result = true>
		</cfif>
		
		<!--- log changes --->
		<cfset doLog('REMOVE CLASS:#LOCAL.alias#')>
		
		<cfreturn result>
	</cffunction>
	
	<cffunction name="new" access="public" returntype="Any" output="false" hint="I return an empty transient bean of given class alias">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		
		<cfset checkDSN()>
		
		<cfset var LOCAL = structNew()>
		
		<!--- CREATE BEAN --->
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.class = VARIABLES.classMap[ARGUMENTS.alias]>
		
		<!--- log changes --->
		<cfset doLog('NEW BEAN:#LOCAL.alias#')>
		
		<!--- getBean --->
		<cfset LOCAL.temp = LOCAL.class.getBean()>

		<cfreturn (LOCAL.temp)>
	</cffunction>
	
	<!--- READ --->
	<cffunction name="read" access="public" returntype="Any" output="false" hint="I return a specific record of the type specified by the alias and the primary key [id]">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="id" required="false" type="String" hint="I am the primary key for the specified class">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		
		<!--- log changes --->
		<!--- <cfset doLog('READ: #LOCAL.alias#')> --->
		
		<!--- create blank bean --->
		<cfset LOCAL.bean = this.new(ARGUMENTS.alias)>
		
		<!--- populate bean --->
		<cfif structKeyExists(ARGUMENTS,'id')>
			<cfset LOCAL.curPKValue = ARGUMENTS.id>
			<!--- <cfset LOCAL.bean.load(ARGUMENTS.id)> --->
			<!--- CHECK CACHE --->
			<cfset LOCAL.cacheKey = '#LOCAL.alias#_#LOCAL.curPKValue#'>
			<cfset LOCAL.cachedObject = cacheGet(LOCAL.cacheKey)>
			<cfif isNull(LOCAL.cachedObject)>
				<cfset LOCAL.bean.load(LOCAL.curPKValue)>
				<cfset cachePut(LOCAL.cacheKey,LOCAL.bean)>
			<cfelse>
				<cfset LOCAL.bean = LOCAL.cachedObject>
			</cfif>
		</cfif>
		
		<cfreturn LOCAL.bean>
	</cffunction>
	
	<cffunction name="readByProperty" access="public" returntype="Any" output="false" hint="I return a specific record of the type identified by the alias matching the unique record identified by the property/value pair">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="property" required="true" type="String" hint="I am the property for the specified class">
		<cfargument name="value" required="true" type="String" hint="I am the value for the property">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.bean = this.new(ARGUMENTS.alias)>
		<!--- CACHE --->
		<cfif structKeyExists(ARGUMENTS,'property') AND structKeyExists(ARGUMENTS,'value')>
			<!--- CHECK CACHE --->
			<cfset LOCAL.cacheKey = '#LOCAL.alias#_#ARGUMENTS.property#_#ARGUMENTS.value#'>
			<cfset LOCAL.cachedObject = cacheGet(LOCAL.cacheKey)>
			<cfif isNull(LOCAL.cachedObject)>
			<cfset LOCAL.bean.load('',ARGUMENTS.property,ARGUMENTS.value)>
			<cfset LOCAL.cacheKey = '#LOCAL.alias#_#LOCAL.bean.getPKValue()#'>
			<cfset cachePut(LOCAL.cacheKey,LOCAL.bean)>
			<cfelse>
				<cfset LOCAL.bean = LOCAL.cachedObject>
			</cfif>
		</cfif>
		
		<!--- <cfset LOCAL.bean.load('',ARGUMENTS.property,ARGUMENTS.value)> --->
		
		<cfreturn LOCAL.bean>
	</cffunction>
	
	<cffunction name="readByPropertyMap"  access="public" returntype="Any" output="false" hint="I return a specific record of the type identified by the alias matching the unique record matching the property/value pairs">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="propertyMap" required="true" type="Struct" hint="I am the property map for the specified class">
		
		<cfset var LOCAL = structNew()>
		
		<cfif NOT isStruct(ARGUMENTS.propertyMap)>
			<cfthrow message="Property map must be supplied as correct data type [struct].">
		</cfif>
	
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.bean = this.new(ARGUMENTS.alias)>
		<!--- CHECK CACHE --->
		<cfset LOCAL.cacheKey = '#LOCAL.alias#_'>
		<cfloop collection="#ARGUMENTS.propertyMap#" item="p">
			<cfset LOCAL.cacheKey = '#LOCAL.cacheKey#_#p#_#ARGUMENTS.propertyMap[p]#'>
		</cfloop>
		<cfset LOCAL.cachedObject = cacheGet(LOCAL.cacheKey)>
		<cfif isNull(LOCAL.cachedObject)>
			<cfset LOCAL.bean.load('',ARGUMENTS.propertyMap)>
			<cfset LOCAL.cacheKey = '#LOCAL.alias#_#LOCAL.bean.getPKValue()#'>
			<cfset cachePut(LOCAL.cacheKey,LOCAL.bean)>
		<cfelse>
			<cfset LOCAL.bean = LOCAL.cachedObject>
		</cfif>
	
		<!--- <cfset LOCAL.bean.load('',ARGUMENTS.propertyMap)> --->
		
		<cfreturn LOCAL.bean>
	</cffunction>
	
	<!--- LIST --->
	<cffunction name="list"  access="public" returntype="Any" output="false" hint="I return an iterator for the records of class type specified by the alias">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNum" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<!--- TODO: review when DSN is able to be set...I think only on setters, not getters like this --->
		<cfargument name="dsn" required="false" type="String" >
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.bean = ''>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.property = ''>
		<cfset LOCAL.propertyValue = ''>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.arrBeans = arrayNew(1)>
		<cfset LOCAL.pkname = 'id'>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<cfset LOCAL.qAll = this.listAsQuery(LOCAL.alias,LOCAL.property,LOCAL.propertyValue,LOCAL.orderProperty,LOCAL.orderAsc,LOCAL.pageSize,LOCAL.pageNumber,LOCAL.start,LOCAL.dsn)>
		<!--- POPULATE ARRAY BY THREAD --->
		<!--- <cfset LOCAL.count = 1>
		<cfloop query="LOCAL.qAll">
			<cfset LOCAL.threadName = '#createUUID()#'>
			<cfset LOCAL.arrTJoin[LOCAL.count] = LOCAL.threadName>
			<cfthread action="run" name="#LOCAL.threadName#" alias="#LOCAL.alias#" query="#LOCAL.qAll#" count="#LOCAL.count#">
				<cfset THREAD.qAll = ATTRIBUTES.query>
				<cfset THREAD.bean = this.new(ATTRIBUTES.alias)>
				<cfset THREAD.pkname = THREAD.bean.getPkName()>
				<cfset THREAD.curPKValue = trim(THREAD.qAll[THREAD.pkname][ATTRIBUTES.count])>
				<cfset THREAD.bean.load(THREAD.curPKValue)>
			</cfthread>
			<cfset LOCAL.count = LOCAL.count+1>
		</cfloop>
		<cfthread action="join" name="#arrayToList(arrTJoin)#"/>
		<cfloop array="#arrTJoin#" index="t">
			<cfset LOCAL.bean = CFTHREAD[t].bean>
			<cfset arrayAppend(LOCAL.arrBeans,LOCAL.bean)>
		</cfloop> --->
		
		<cfloop query="LOCAL.qAll">
			<!--- <cfset LOCAL.bean = this.new(LOCAL.alias)> --->
			<cfset LOCAL.pkname = LOCAL.class.getPkName()>
			<cfset LOCAL.curPKValue = trim(LOCAL.qAll[LOCAL.pkname][LOCAL.qAll.CURRENTROW])>

			<cfset LOCAL.bean = read(LOCAL.alias,LOCAL.curPKValue)>
			
			<cfset arrayAppend(LOCAL.arrBeans,LOCAL.bean)>
		</cfloop>

		<cfreturn iterator(LOCAL.arrBeans,LOCAL.class)>
	</cffunction>
	
	<cffunction name="listByProperty"  access="public" returntype="Any" output="false" hint="I return an iterator of records that meet the property/value pair">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="property" required="false" type="String" hint="I am the property/column to check">
		<cfargument name="propertyValue" required="false" type="Any" hint="I am the value found in property argument to identify the record">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNumber" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<cfargument name="dsn" required="false" type="String">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.bean = ''>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.property = ''>
		<cfset LOCAL.propertyValue = ''>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.arrBeans = arrayNew(1)>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'property')>
			<cfset LOCAL.property = ARGUMENTS.property>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'propertyValue')>
			<cfset LOCAL.propertyValue = ARGUMENTS.propertyValue>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<cfset LOCAL.qAll = this.listAsQuery(LOCAL.alias,LOCAL.property,LOCAL.propertyValue,LOCAL.orderProperty,LOCAL.orderAsc,LOCAL.pageSize,LOCAL.pageNumber,LOCAL.start,LOCAL.dsn)>

		<cfloop query="LOCAL.qAll">
			<!--- <cfset LOCAL.bean = this.new(LOCAL.alias)> --->
			<cfset LOCAL.bean = read(LOCAL.alias,LOCAL.qAll.id)>
			<cfset arrayAppend(LOCAL.arrBeans,LOCAL.bean)>
		</cfloop>
		
		<cfreturn iterator(LOCAL.arrBeans,LOCAL.class)>
	</cffunction>
	
	<cffunction name="listByPropertyMap" access="public" returntype="Any" output="false" hint="I return an iterator of records that meet the property/value pair in the Property Map">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="propertyMap" required="false" type="Struct" hint="I am the property map to identify the record">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNumber" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<cfargument name="dsn" required="false" type="String">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.bean = ''>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.propertyMap = structNew()>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.arrBeans = arrayNew(1)>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'propertyMap')>
			<cfset LOCAL.propertyMap = ARGUMENTS.propertyMap>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<!--- <cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()> --->
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<cfset LOCAL.qAll = this.listByPropertyMapAsQuery(LOCAL.alias,LOCAL.propertyMap,LOCAL.orderProperty,LOCAL.orderAsc,LOCAL.pageSize,LOCAL.pageNumber,LOCAL.start,LOCAL.dsn)>

		<cfloop query="LOCAL.qAll">
			<!--- <cfset LOCAL.bean = this.new(LOCAL.alias)> --->
			<cfset LOCAL.bean = read(LOCAL.alias,LOCAL.qAll.id)>
			<cfset arrayAppend(LOCAL.arrBeans,LOCAL.bean)>
		</cfloop>
		
		<cfreturn iterator(LOCAL.arrBeans,LOCAL.class)>
	</cffunction>

	<cffunction name="listByDirectiveMap" access="public" returntype="Any" output="false" hint="I return an iterator of records that meet the property/value pair in the Directive Map">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="directiveMap" required="true" type="Struct" hint="I am the property directive structure identifying the instructions and value pairs. Options:AND,OR,ANDNOT,ORNOT,BETWEEN,GREATERTHAN,GREATERTHANOREQUAL,LESSTHAN,LESSTHANOREQUAL,IN,LIKE">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNumber" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<cfargument name="dsn" required="false" type="String">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.bean = ''>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.directiveMap = structNew()>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.arrBeans = arrayNew(1)>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'directiveMap')>
			<cfset LOCAL.directiveMap = ARGUMENTS.directiveMap>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<cfset LOCAL.qAll = this.listByDirectiveMapAsQuery(LOCAL.alias,LOCAL.directiveMap,LOCAL.orderProperty,LOCAL.orderAsc,LOCAL.pageSize,LOCAL.pageNumber,LOCAL.start,LOCAL.dsn)>

		<cfloop query="LOCAL.qAll">
			<!--- <cfset LOCAL.bean = this.new(LOCAL.alias)> --->
			<cfset LOCAL.bean = read(LOCAL.alias,LOCAL.qAll.id)>
			<cfset arrayAppend(LOCAL.arrBeans,LOCAL.bean)>
		</cfloop>
		
		<cfreturn iterator(LOCAL.arrBeans,LOCAL.class)>
	</cffunction>
	
	<cffunction name="listAsQuery" access="public" returntype="Any" output="false" hint="I return a query matching the property/value pair">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="property" required="false" type="String" hint="I am the property/column to check">
		<cfargument name="propertyValue" required="false" type="Any" hint="I am the unique value found in property argument to identify the record">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNumber" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<cfargument name="dsn" required="false" type="String">

		<cfset checkDSN()>
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.property = ''>
		<cfset LOCAL.propertyValue = ''>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'property')>
			<cfset LOCAL.property = ARGUMENTS.property>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'propertyValue')>
			<cfset LOCAL.propertyValue = ARGUMENTS.propertyValue>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<!--- <cfquery name="LOCAL.qAll" datasource="#LOCAL.dsn#" cachedWithin="#LOCAL.class.tsOfLastPersistence()#"> --->
		<cfquery name="LOCAL.qAll" datasource="#LOCAL.dsn#">
			SELECT * FROM #LOCAL.table#
			<cfif len(LOCAL.property)>
			WHERE #colWrapper(LOCAL.property)# = <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.property)#" value="#LOCAL.propertyValue#">
			</cfif>
			<cfif len(LOCAL.orderProperty)>
			ORDER BY #colWrapper(LOCAL.orderProperty)# <cfif LOCAL.orderAsc>ASC<cfelse>DESC</cfif>
			</cfif>
			<cfif LOCAL.pageSize GTE 0  AND determineDBType() EQ 'MySQL'>
			LIMIT <cfif LOCAL.start GT 0>#LOCAL.start#,</cfif>#LOCAL.pageSize#
			</cfif>
		</cfquery>
		
		<cfreturn LOCAL.qAll>
	</cffunction>
	
	<cffunction name="listByPropertyMapAsQuery" access="public" returntype="Any" output="false" hint="I return a query matching the property/value pairs in the Property Map">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="propertyMap" required="true" type="Struct" hint="I am the property map to identify the record">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNumber" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<cfargument name="dsn" required="false" type="String">
		
		<cfset checkDSN()>
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.propertyMap = structNew()>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'propertyMap')>
			<cfset LOCAL.propertyMap = ARGUMENTS.propertyMap>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<cfquery name="LOCAL.qAll" datasource="#LOCAL.dsn#">
			SELECT * FROM #LOCAL.table#
			WHERE 1=1
			<cfloop collection="#LOCAL.propertyMap#" item="p">
			AND #colWrapper(p)# = <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(p)#" value="#LOCAL.propertyMap[p]#">
			</cfloop>
			<cfif len(LOCAL.orderProperty)>
			ORDER BY #colWrapper(LOCAL.orderProperty)# <cfif LOCAL.orderAsc>ASC<cfelse>DESC</cfif>
			</cfif>
			<cfif LOCAL.pageSize GTE 0 AND determineDBType() EQ 'MySQL'>
			LIMIT <cfif LOCAL.start GT 0>#LOCAL.start#,</cfif>#LOCAL.pageSize#
			</cfif>
		</cfquery>
		
		<cfreturn LOCAL.qAll>
	</cffunction>
	
	<cffunction name="listByDirectiveMapAsQuery" access="public" returntype="Any" output="false" hint="I return a query matching the property/value pairs in the Property Directive">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		<cfargument name="directiveMap" required="true" type="Struct" hint="I am the property directive structure identifying the instructions and value pairs. Options:AND,OR,ANDNOT,ORNOT,BETWEEN,GREATERTHAN,GREATERTHANOREQUAL,LESSTHAN,LESSTHANOREQUAL,IN,LIKE">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		<cfargument name="pageSize" required="false" type="Numeric" hint="I specify the starting row of the records to return">
		<cfargument name="pageNumber" required="false" type="Numeric" hint="I specify the page number. Used with pageSize.">
		<cfargument name="start" required="false" type="Numeric" hint="I specify the starting row of the records to return. Overwrites pageNum if specified.">
		<cfargument name="dsn" required="false" type="String">
		
		<cfset checkDSN()>
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.qAll = ''>
		<cfset LOCAL.dsn = ''>
		<cfset LOCAL.directiveMap = structNew()>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		<cfset LOCAL.class = this.getClass(LOCAL.alias)>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.pageSize = -1>
		<cfset LOCAL.start = -1>
		<cfset LOCAL.pageNumber = -1>
		
		<cfif structKeyExists(ARGUMENTS,'directiveMap')>
			<cfset LOCAL.directiveMap = ARGUMENTS.directiveMap>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageSize')>
			<cfset LOCAL.pageSize = ARGUMENTS.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'pageNumber')>
			<cfset LOCAL.pageNumber = ARGUMENTS.pageNumber>
			<cfset LOCAL.start = ARGUMENTS.pageNumber * LOCAL.pageSize>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'start')>
			<cfset LOCAL.start = ARGUMENTS.start>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'dsn')>
			<cfset LOCAL.dsn = ARGUMENTS.dsn>
		<cfelseif len(this.getDSN()) LT 1>
			<cfset LOCAL.dsn = LOCAL.class.getDSN()>
		<cfelse>
			<cfset LOCAL.dsn = this.getDSN()>
		</cfif>
		
		<!--- EXECUTE QUERY --->
		<cfquery name="LOCAL.qAll" datasource="#LOCAL.dsn#">
			SELECT * FROM #LOCAL.table#
			WHERE 1=1
			<cfif structKeyExists(LOCAL.directiveMap,'AND')>
				<cfloop collection="#LOCAL.directiveMap.AND#" item="p">
				AND #colWrapper(p)# = <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(p)#" value="#LOCAL.directiveMap.AND[p]#">
				</cfloop>
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'OR')>
				<cfloop collection="#LOCAL.directiveMap.OR#" item="p">
				OR #colWrapper(p)# = <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(p)#" value="#LOCAL.directiveMap.OR[p]#">
				</cfloop>
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'ANDNOT')>
				<cfloop collection="#LOCAL.directiveMap.ANDNOT#" item="p">
				AND #colWrapper(p)# != <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(p)#" value="#LOCAL.directiveMap.ANDNOT[p]#">
				</cfloop>
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'ORNOT')>
				<cfloop collection="#LOCAL.directiveMap.ORNOT#" item="p">
				OR #colWrapper(p)# != <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(p)#" value="#LOCAL.directiveMap.ORNOT[p]#">
				</cfloop>
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'BETWEEN')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.BETWEEN,'gate')><cfset LOCAL.directiveMap.BETWEEN.gate = 'AND'></cfif>
				#LOCAL.directiveMap.BETWEEN.gate# #colWrapper(LOCAL.directiveMap.BETWEEN.property)# BETWEEN
				<cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.BETWEEN.property)#" value="#LOCAL.directiveMap.BETWEEN.min#">
				AND <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.BETWEEN.property)#" value="#LOCAL.directiveMap.BETWEEN.max#">
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'GREATERTHAN')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.GREATERTHAN,'gate')><cfset LOCAL.directiveMap.GREATERTHAN.gate = 'AND'></cfif>
				#LOCAL.directiveMap.GREATERTHAN.gate# #colWrapper(LOCAL.directiveMap.GREATERTHAN.property)# >
				<cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.GREATERTHAN.property)#" value="#LOCAL.directiveMap.GREATERTHAN.value#">
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'GREATERTHANOREQUAL')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.GREATERTHANOREQUAL,'gate')><cfset LOCAL.directiveMap.GREATERTHANOREQUAL.gate = 'AND'></cfif>
				#LOCAL.directiveMap.GREATERTHANOREQUAL.gate# #colWrapper(LOCAL.directiveMap.GREATERTHANOREQUAL.property)# >=
				<cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.GREATERTHANOREQUAL.property)#" value="#LOCAL.directiveMap.GREATERTHANOREQUAL.value#">
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'LESSTHAN')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.LESSTHAN,'gate')><cfset LOCAL.directiveMap.LESSTHAN.gate = 'AND'></cfif>
				#LOCAL.directiveMap.LESSTHAN.gate# #colWrapper(LOCAL.directiveMap.LESSTHAN.property)# <
				<cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.LESSTHAN.property)#" value="#LOCAL.directiveMap.LESSTHAN.value#">
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'LESSTHANOREQUAL')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.LESSTHANOREQUAL,'gate')><cfset LOCAL.directiveMap.LESSTHANOREQUAL.gate = 'AND'></cfif>
				#LOCAL.directiveMap.LESSTHANOREQUAL.gate# #colWrapper(LOCAL.directiveMap.LESSTHANOREQUAL.property)# <
				<cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.LESSTHANOREQUAL.property)#" value="#LOCAL.directiveMap.LESSTHANOREQUAL.value#">
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'IN')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.IN,'gate')><cfset LOCAL.directiveMap.IN.gate = 'AND'></cfif>
				#LOCAL.directiveMap.IN.gate# #colWrapper(LOCAL.directiveMap.IN.property)# IN
				(<cfqueryparam list="true" value="#trim(LOCAL.directiveMap.IN.value)#">)
			</cfif>
			<cfif structKeyExists(LOCAL.directiveMap,'LIKE')>
				<cfif NOT structKeyExists(LOCAL.directiveMap.LIKE,'gate')><cfset LOCAL.directiveMap.LIKE.gate = 'AND'></cfif>
				#LOCAL.directiveMap.LIKE.gate# #colWrapper(LOCAL.directiveMap.LIKE.property)# LIKE
				(<cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.directiveMap.LIKE.property)#" value="#LOCAL.directiveMap.LIKE.value#">)
			</cfif>
			<cfif len(LOCAL.orderProperty)>
			ORDER BY #colWrapper(LOCAL.orderProperty)# <cfif LOCAL.orderAsc>ASC<cfelse>DESC</cfif>
			</cfif>
			<cfif LOCAL.pageSize GTE 0 AND determineDBType() EQ 'MySQL'>
			LIMIT <cfif LOCAL.start GT 0>#LOCAL.start#,</cfif>#LOCAL.pageSize#
			</cfif>
		</cfquery>
		
		<cfreturn LOCAL.qAll>
	</cffunction>
	
	
	<!--- TODO: add functions for managing the relationships from factory level --->
	
	<!--- UTILITY --->
	<cffunction name="iterator"  access="public" returntype="synapse.SynapseListIterator" output="false" hint="I return the iterator of collection past in">
		<cfargument name="collection" required="true" type="Any" hint="I am the collection to return as an iterator">
		<cfargument name="class" required="true" type="synapse.SynapseClass">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.iterator = createObject("component",'synapse.SynapseListIterator').init(ARGUMENTS.collection,ARGUMENTS.class)>
		<cfreturn LOCAL.iterator>
	</cffunction>
	
	<cffunction name="setDSN" access="public" returntype="void" output="false" hint="I set/override the default datasource">
		<cfargument name="dsn" required="false" type="String" hint="I am the default datasource if you don't specify a datasource in other functions">
			<cfset VARIABLES.dsn = ARGUMENTS.dsn>
	</cffunction>
	
	<cffunction name="getDSN" access="public" returntype="String" output="false" hint="I return the name of the default datasource">
		<cfset checkDSN()>
		<cfreturn VARIABLES.dsn>
	</cffunction>
	
	<cffunction name="getClass" access="public" returntype="Any" output="false" hint="I return an empty class of given alias">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used for the class type to return">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.class = VARIABLES.classMap[ARGUMENTS.alias]>
		<cfreturn (LOCAL.class)>
	</cffunction>
	
	<cffunction name="getClassKeys" access="public" returntype="Array" output="false" hint="I return an array of the alias names used for the persistence classes">
		<cfreturn structKeyArray(VARIABLES.classMap)>
	</cffunction>
	
	<cffunction name="determineDBType"  access="private" returntype="String" output="false" hint="I return the DB type for this classes datasource name">
		<cfset checkDSN()>
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
	
	<cffunction name="colWrapper"  access="private" returntype="String" output="false" hint="I return the DB type for this classes datasource name">
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
	
	<cffunction name="doLog" access="private" output="false" returntype="void">
		<cfargument name="label" required="false" default="none">
		
		<!--- log mem --->
		<cfif VARIABLES.memlog>
			<cfset logMemoryStatus('FACTORY/#ARGUMENTS.label#')>
		</cfif>
		
	</cffunction>

	<cffunction name="logMemoryStatus" access="private" output="false" returntype="void">
		<cfargument name="label" required="false" default="none">
		
		<cfset var LOCAL = structNew()>
		<!--- NEW FILENAME EACH DAY --->
		<cfset LOCAL.filename = "#dateFormat(now(),'yyyy-mm-dd')#.txt">
		<!--- CREATE DATE AND TIME STRING FOR LOG --->
		<cfset LOCAL.datetime = "#dateFormat(now(),'yyyy-mm-dd')# #timeFormat(now(),'medium')#">
		<!--- CALL UNDERLYING JAVA RUNTIME --->
		<cfset LOCAL.runTime = createObject("java","java.lang.Runtime").getRuntime()>
		<!--- GET FREE MEMORY FROM THE RUNTIME --->
		<cfset LOCAL.freeMem = LOCAL.runtime.freememory()/>
		<!--- COVERT TO MB --->
		<cfset LOCAL.freeMem = int((LOCAL.freeMem/1024)/1024)/>
		<!--- CREATE STRING TO LOG --->
		<cfsavecontent variable="LOCAL.toFile">
			<cfoutput>#LOCAL.datetime#] Free: #LOCAL.freeMem# MB (#ARGUMENTS.label#)</cfoutput>
		</cfsavecontent>
		<!--- WRITE TO FILE --->
		<cffile action="append" addnewline="true" file="/synapse/log/#LOCAL.filename#" output="#trim(LOCAL.toFile)#">
	</cffunction>
	
	<cffunction name="checkDSN" access="private" returntype="void" output="false" hint="I throw an error if the dsn is not set">
		
		<cfif NOT structKeyExists(VARIABLES,'dsn')>
			<cfthrow message="VARIABLES.dsn does not exists">
		</cfif>
		<cfif len(VARIABLES.dsn) EQ 0>
			<cfthrow message="VARIABLES.dsn not set">
		</cfif>
	</cffunction>
</cfcomponent>