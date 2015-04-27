<!---
	Name         	: SynapseBean.cfc
	Author       	: deebo
	Created      	: 4/20/2010 7:02:37 AM
	Last Updated 	: 4/10/2011 14:07:37 AM
	Purpose	 		: Accessors and Mutator functionality for ORM classes
					: Sets isPersisted to false on mutation
					: Populate this bean based on struct passed in
	History      	: 8/7/2010 Added functions calling reference to SynapseClass
					: - Now handles transient info with explicit functions, and calls class ref where necessary, 
						this will hopefully cause a much smaller memory footprint
					: bug fix: heap memory error	changed child/parent/sibling ref to a class, then getBean from Class (flywheel pattern)
					: 8/9/2010 added order property for getChildren and reqorked to make use of query function
					: made keyword safe
					: 8/16/2010 added decorator feature
					: 2/27/2011 added get/setLinkValue
					: 3/17/2011 added getPersistedValues
					: 4/8/2011 added useCache (caching can be turned on/off). 
					: - create(), update(), delete(), now returning Boolean value of last Interceptor called
					: - moved persistSiblingLinks call in the save function so it only calls if the beforeSynapseSave() interceptor is true
					: - fixed defect '1 - Join table field reset' by drastically changing persistSiblings()
					: 4/11/2011 fixed a bug where an error is thrown in sql if a property name is '', it can be set still but will not be included in the insert and update query
					: 4/12/2011 added <cfset LOCAL.child = javaCast("null",0)> to load(),getChildren(),getSiblings()
--->
<cfcomponent output="false">
	<cfset VARIABLES.class = ''>
	<cfset VARIABLES.isPersisted = false>
	<cfset VARIABLES.useCache = false>
	
	<cffunction name="init" access="public" returntype="Any" output="false" hint="I initialize a class to a table">
		<cfargument name="class" required="true" type="synapse.SynapseClass">
		
		<cfset VARIABLES.class = ARGUMENTS.class>
		<cfset VARIABLES.useCache = VARIABLES.class.useCache()>
		<cfset reset()>
		
		<!--- INTERCEPTOR --->
		<cfif VARIABLES.class.hasInterceptor()>
			<cfset this.decorate(VARIABLES.class.getInterceptor())>
		<cfelse>
			<cfset this.decorate(createObject("component","synapse.SynapseInterceptor"))>
		</cfif>
		
		<cfset doLog('INIT #getAlias()#')>
		
		<cfreturn this>
	</cffunction>
	
	<cffunction name="generateID" access="private" returntype="Any" output="false" hint="I generate a id for a new record">
		<cfreturn VARIABLES.class.generateID()>
	</cffunction>
	<!--- ACCSESSORS AND MUTATORS --->
	
	<cffunction name="getDSN"  access="public" returntype="String" output="false" hint="I return the default datasource name">
		<cfreturn VARIABLES.class.getDSN()>
	</cffunction>
	
	<cffunction name="getTable"  access="public" returntype="String" output="false" hint="I return the name of this classes table">
		<cfreturn VARIABLES.class.getTable()>
	</cffunction>
	
	<cffunction name="getAlias"  access="public" returntype="String" output="false" hint="I return this classes alias">
		<cfreturn VARIABLES.class.getAlias()>
	</cffunction>
	
	<cffunction name="getPKType" access="public" returntype="String" output="false" hint="I return the primary key type (option: manual,auto-uuid)">
		<cfreturn VARIABLES.class.getPKType()>
	</cffunction>
	
	<cffunction name="getProperties" access="public" returntype="Array" output="false" hint="I return a list of this classes properties/columns">
		<cfreturn VARIABLES.class.getProperties()>
	</cffunction>
	
	<cffunction name="isPersisted" access="public" returntype="Boolean" output="false" hint="I return or set whether this class has been persisted to the database">
		<cfargument name="status" required="false" type="Boolean" hint="If I am parsed, I set the isPersisted status, else I return the current status">
		<cfif structKeyExists(ARGUMENTS,'status')>
			<cfset VARIABLES.isPersisted = ARGUMENTS.status>
		</cfif>
		<cfreturn VARIABLES.isPersisted>
	</cffunction>
	
	<cffunction name="getLinkValue" access="public" returntype="Any" output="false" hint="I return a value from a custom column in a linking table between siblings">
		<cfargument name="siblingalias" required="true" type="String" hint="I am the alias used to reference the sibling class">
		<cfargument name="foreignkey" required="true" type="String" hint="I am the foreign key value/id for the sibling">
		<cfargument name="column" required="true" type="String" hint="I am the name of the column in the linking table">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.qTemp = "">
		
		<!--- GET CLASS LINK --->
		<cfset LOCAL.link = this.getClass().getSiblingLink(ARGUMENTS.siblingalias)>
		<cfset LOCAL.sibling = link.getORMClass()>
		<!--- QUERY LINKING TABLE --->
		<cfquery name="LOCAL.qTemp" datasource="#this.getDSN()#">
			SELECT #ARGUMENTS.column# AS result
			FROM #LOCAL.link.getLinkTable()#
			WHERE #LOCAL.link.getForeignKeyName()# = <cfqueryparam cfsqltype="#this.getQueryParamType(this.getPKName())#" value="#this.getID()#">
			AND #LOCAL.link.getLinkForeignKeyName()# = <cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(LOCAL.sibling.getPKName())#" value="#ARGUMENTS.foreignkey#">
		</cfquery>
		
		<cfreturn LOCAL.qTemp.result>
	</cffunction>
	
	<cffunction name="setLinkValue" access="public" returntype="Boolean" output="false" hint="I return a value from a custom column in a linking table between siblings">
		<cfargument name="siblingalias" required="true" type="String" hint="I am the alias used to reference the sibling class">
		<cfargument name="foreignkey" required="true" type="String" hint="I am the foreign key value/id for the sibling">
		<cfargument name="column" required="true" type="String" hint="I am the name of the column in the linking table">
		<cfargument name="value" required="true" type="Any" hint="I am the name of the value to be inserted">
		<cfargument name="createlink" required="false" default="false" type="Boolean" hint="I am the indicator of whether to create the link if it doesn't exist">
		
		<cfset var tableInfo = "">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.qTemp = "">
		
		<!--- GET CLASS LINK --->
		<cfset LOCAL.link = this.getClass().getSiblingLink(ARGUMENTS.siblingalias)>
		<cfset LOCAL.sibling = link.getORMClass()>
		
		<!--- GET COLUMN TYPE --->
		<cfdbinfo datasource="#this.getDSN()#" name="tableInfo" table="#LOCAL.link.getLinkTable()#" type="Columns">
		<cfquery name="LOCAL.qType" dbtype="query">
			SELECT type_name FROM tableInfo
			WHERE column_name = '#ARGUMENTS.column#'
		</cfquery>
		<cfset LOCAL.colType = convertDBToQueryType(LOCAL.qType.type_name)>
		
		<cfquery name="LOCAL.qTemp" datasource="#this.getDSN()#">
			SELECT #ARGUMENTS.column#
			FROM #LOCAL.link.getLinkTable()#
			WHERE #LOCAL.link.getForeignKeyName()# = <cfqueryparam cfsqltype="#this.getQueryParamType(this.getPKName())#" value="#this.getID()#">
			AND #LOCAL.link.getLinkForeignKeyName()# = <cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(LOCAL.sibling.getPKName())#" value="#ARGUMENTS.foreignkey#">
		</cfquery>
		
		<cfif queryCount(LOCAL.qTemp) EQ 0>
			<!--- QUERY LINKING TABLE --->
			<cfquery name="LOCAL.qTemp" datasource="#this.getDSN()#">
				INSERT INTO #LOCAL.link.getLinkTable()#
				(#LOCAL.link.getForeignKeyName()#,#LOCAL.link.getLinkForeignKeyName()#,#ARGUMENTS.column#)
				VALUES (<cfqueryparam cfsqltype="#this.getQueryParamType(this.getPKName())#" value="#this.getID()#">,
				<cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(LOCAL.sibling.getPKName())#" value="#ARGUMENTS.foreignkey#">,
				<cfqueryparam cfsqltype="#LOCAL.colType#" value="#ARGUMENTS.value#">)
			</cfquery>
		<cfelse>
			<!--- QUERY LINKING TABLE --->
			<cfquery name="LOCAL.qTemp" datasource="#this.getDSN()#">
				UPDATE #LOCAL.link.getLinkTable()#
				SET #ARGUMENTS.column# = <cfqueryparam cfsqltype="#LOCAL.colType#" value="#ARGUMENTS.value#">
				WHERE #LOCAL.link.getForeignKeyName()# = <cfqueryparam cfsqltype="#this.getQueryParamType(this.getPKName())#" value="#this.getID()#">
				AND #LOCAL.link.getLinkForeignKeyName()# = <cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(LOCAL.sibling.getPKName())#" value="#ARGUMENTS.foreignkey#">
			</cfquery>
		</cfif>
		
		
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="useCache" access="public" returntype="Boolean" output="false" hint="I return whether caching is used">
		<cfreturn VARIABLES.class.useCache()>
	</cffunction>
	
	<!--- GET OBJECTS/LISTS/QUERIES FROM RELATIONS --->
	<cffunction name="getChildren"  access="public" returntype="Array" output="false" hint="I return an array of the requested(by alias) children">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getChildren()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfset LOCAL.qChildren = getChildrenAsQuery(LOCAL.alias,LOCAL.orderProperty,LOCAL.orderAsc)>
		<cfset LOCAL.testlist = ''>
		<cfloop query="LOCAL.qChildren">
			<!--- CHECK CACHE --->
			<cfset LOCAL.child = javaCast("null",0)>
			<cfif this.useCache()>
				<cfset LOCAL.cacheKey = '#LOCAL.class.getAlias()#_#LOCAL.qChildren[LOCAL.class.getPKName()]#'>
				<cfset LOCAL.child = cacheGet(LOCAL.cacheKey)>
			</cfif>
			<!--- IF NOT CACHED --->
			<cfif isNull(LOCAL.child)>
				<cfset LOCAL.child = LOCAL.class.getBean()>
				<cfset LOCAL.child.load(LOCAL.qChildren[LOCAL.child.getPKName()])>
				<!--- CACHE IT --->
				<cfif this.useCache()>
					<cfset cachePut(LOCAL.cacheKey,LOCAL.child)>
				</cfif>
			</cfif>
			<cfset arrayAppend(LOCAL.arrResult,(LOCAL.child))>
		</cfloop>
		
		<cfreturn LOCAL.arrResult>
	</cffunction>
	
	<cffunction name="getChildrenIterator"  access="public" returntype="Any" output="false" hint="I return an iterator of the requested(by alias) children">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getChildren()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfset LOCAL.arrResult = getChildren(LOCAL.alias,LOCAL.orderProperty,LOCAL.orderAsc)>
		
		<cfreturn iterator(LOCAL.arrResult,LOCAL.class)>
	</cffunction>
	
	<cffunction name="getChildrenAsQuery"  access="public" returntype="Query" output="false" hint="I return a query of the requested(by alias) children">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getChildren()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.fkname = LOCAL.link.getForeignKeyName()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		<cfset qChildren = "">
		
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<!--- <cfquery name="LOCAL.qChildren" datasource="#this.getDSN()#" cachedWithin="#LOCAL.class.tsOfLastPersistence()#"> --->
		<cfquery name="LOCAL.qChildren" datasource="#this.getDSN()#">
			SELECT * FROM #LOCAL.table#
			WHERE #colWrapper(LOCAL.fkname)# = <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(LOCAL.fkname)#" value="#this.getPKValue()#">
			<cfif len(LOCAL.orderProperty)>
			ORDER BY #colWrapper(LOCAL.orderProperty)# <cfif LOCAL.orderAsc>ASC<cfelse>DESC</cfif>
			</cfif>
		</cfquery>
		
		<cfreturn LOCAL.qChildren>
	</cffunction>
	
	<cffunction name="getSiblings" access="public" returntype="Array" output="false" hint="I return an array of the requested(by alias) siblings(many-to-many)">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getSiblings()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfset LOCAL.qSiblings = this.getSiblingsAsQuery(LOCAL.alias,LOCAL.orderProperty,LOCAL.orderAsc)>
		
		<cfloop query="LOCAL.qSiblings">
			<!--- CHECK CACHE --->
			<cfset LOCAL.sibling = javaCast("null",0)>
			<cfif this.useCache()>
				<cfset LOCAL.cacheKey = '#LOCAL.class.getAlias()#_#LOCAL.qSiblings[LOCAL.class.getPKName()]#'>
				<cfset LOCAL.sibling = cacheGet(LOCAL.cacheKey)>
			</cfif>
			<cfif isNull(LOCAL.sibling)>
				<cfset LOCAL.sibling = LOCAL.class.getBean()>
				<cfset LOCAL.sibling.load(qSiblings[LOCAL.sibling.getPKName()])>
				<!--- CACHE IT --->
				<cfif this.useCache()>
					<cfset cachePut(LOCAL.cacheKey,LOCAL.sibling)>
				</cfif>
			</cfif>
			<cfset arrayAppend(LOCAL.arrResult,LOCAL.sibling)>
		</cfloop>
		
		<cfreturn LOCAL.arrResult>
	</cffunction>
	
	<cffunction name="getSiblingIterator" access="public" returntype="Any" output="false" hint="I return an iterator of the requested(by alias) siblings(many-to-many)">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">
				
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getSiblings()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfset LOCAL.arrResult = this.getSiblings(LOCAL.alias,LOCAL.orderProperty,LOCAL.orderAsc)>
		
		<cfreturn iterator(LOCAL.arrResult,LOCAL.class)>
	</cffunction>
	
	<cffunction name="getSiblingsAsQuery" access="public" returntype="Query" output="false" hint="I return a query of the requested(by alias) siblings(many-to-many)">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		<cfargument name="orderProperty" required="false" type="String" hint="I am the property/column by which the returned results will be ordered">
		<cfargument name="orderAsc" required="false" type="Boolean" hint="I specify whether the orderProperty ordering is done in ascending or descending">	
			
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getSiblings()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.table = LOCAL.class.getTable()>
		<cfset LOCAL.fkname = LOCAL.link.getForeignKeyName()>
		<cfset LOCAL.linktable = LOCAL.link.getLinkTable()>
		<cfset LOCAL.linkfkname = LOCAL.link.getLinkForeignKeyName()>
		
		<cfset LOCAL.orderProperty = ''>
		<cfset LOCAL.orderAsc = true>
		
		<cfif structKeyExists(ARGUMENTS,'orderProperty')>
			<cfset LOCAL.orderProperty = ARGUMENTS.orderProperty>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'orderAsc')>
			<cfset LOCAL.orderAsc = ARGUMENTS.orderAsc>
		</cfif>
		
		<cfquery name="qSiblings" datasource="#this.getDSN()#">
			SELECT <!--- #LOCAL.sibling.getPKName()# --->* 
			FROM #LOCAL.table#
			WHERE #colWrapper(LOCAL.class.getPKName())# IN (
											SELECT #colWrapper(LOCAL.linkfkname)#
											FROM #LOCAL.linktable#
											WHERE #colWrapper(LOCAL.fkname)# = <cfqueryparam cfsqltype="#LOCAL.class.getQueryParamType(this.getPKName())#" value="#this.getPKValue()#">
											)
			<cfif len(LOCAL.orderProperty)>
			ORDER BY #colWrapper(LOCAL.orderProperty)# <cfif LOCAL.orderAsc>ASC<cfelse>DESC</cfif>
			</cfif>
		</cfquery>
		
		<cfreturn qSiblings>
	</cffunction>
	
	<cffunction name="getParent"  access="public" returntype="Any" output="false" hint="I return a object of the requested(by alias) Parent">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getParents()[LOCAL.alias]>
		<cfset LOCAL.class = LOCAL.link.getORMClass()>
		<cfset LOCAL.fkname = LOCAL.link.getForeignKeyName()>
		<cfset LOCAL.parent = LOCAL.class.getBean()>
		<cfset LOCAL.parent.load(VARIABLES[LOCAL.fkname])>
		
		<cfreturn LOCAL.parent>
	</cffunction>
	
	<!--- CRUD --->
	<cffunction name="load"  access="public" returntype="Any" output="false" hint="I populate the class with the data matching the given primary key">
		<cfargument name="id" type="Any" required="false" hint="The ID of the record to get">
		<cfargument name="property" type="any" required="false" hint="Used with value argument to get a object with a property with a specific value">
		<cfargument name="value" type="string" required="false" hint="Used with property argument to get a object with a property with a specific value">
		
		<cfset var LOCAL = structNew()>
		<cfset var qSelect = ''>
		
		<!--- DETERMINE PK --->
		<cfif structKeyExists(ARGUMENTS,'property') AND structKeyExists(ARGUMENTS,'value')>
			<!--- by property --->
			<cfset LOCAL.id = getPKValueByProperty(ARGUMENTS.property,ARGUMENTS.value)>
		<cfelseif structKeyExists(ARGUMENTS,'property') AND NOT structKeyExists(ARGUMENTS,'value')>
			<cfif NOT isStruct(ARGUMENTS.property)>
				<cfthrow message="Property map must be supplied">
			</cfif>
			<!--- by property map --->
			<cfset LOCAL.id = getPKValueByProperty(ARGUMENTS.property)>
		<cfelse>
			<!--- VALIDATION --->
			<cfif NOT structKeyExists(ARGUMENTS,"id")>
				<cfthrow message="No ID supplied to retrieve the record.">
			</cfif>
			<!--- by primary key --->
			<cfset LOCAL.id = ARGUMENTS.id>
		</cfif>
		
		<!--- OTHER VARIABLES --->
		<cfset LOCAL.tempStruct = structNew()>
		<cfset LOCAL.queryStatement = ''>
		<cfset LOCAL.dsn = getDSN()>
		<cfset LOCAL.pkname = getPKName()>
		
		<!--- OBJECT CACHING --->
		<cfset LOCAL.cachedobject = javaCast("null",0)>
		<cfif this.useCache()>
			<cfset LOCAL.cacheKey = '#VARIABLES.class.getAlias()#_#LOCAL.id#'>
			<cfset LOCAL.cachedObject = cacheGet(LOCAL.cacheKey)>
		</cfif>
		<!--- INTERCEPTOR: beforeSynapseLoad --->
		<cfif this.beforeSynapseLoad() EQ true>
			<!--- <cfthrow message="load2"> --->
			<cfif isNull(LOCAL.cachedObject)>
				<cfset LOCAL.iterator = getProperties().iterator()>
				
				<cfquery datasource="#LOCAL.dsn#" name="qSelect" >
					<cfsavecontent variable="LOCAL.queryStatement">
					<cfoutput>
					SELECT 
					<cfloop condition="#LOCAL.iterator.hasNext()#">
						<cfoutput>#colWrapper(LOCAL.iterator.next())#<cfif LOCAL.iterator.hasNext()>,</cfif></cfoutput>
					</cfloop>
					FROM #getTable()#
					WHERE #colWrapper(LOCAL.pkname)# = <cfqueryparam cfsqltype="#this.getQueryParamType(LOCAL.pkname)#" value="#LOCAL.id#">
					
					</cfoutput>
					</cfsavecontent>
					<cfoutput>#LOCAL.queryStatement#</cfoutput>
				</cfquery>
				<!--- INTERCEPTOR: aferSynapseLoadTransaction --->
				<cfset this.afterSynapseLoadTransaction()>
				<!--- <cfthrow message="#LOCAL.queryStatement# - #this.getQueryParamType(LOCAL.pkname)# - #ARGUMENTS.id#"> --->
				
				<cfif queryCount(qSelect) GT 1>
					<cfthrow message="Read returned multiple possible values.">
				<cfelseif queryCount(qSelect) EQ 1>
					<cfset LOCAL.tempStruct = queryToStruct(qSelect,0)>
					<cfset internalPopulate(LOCAL.tempStruct[1])>
				<cfelse>
					<cfset this.reset()>
				</cfif>
				<cfset this.isPersisted(true)>
				<cfif this.useCache()>
					<cfset cachePut(cacheKey,this)>
				</cfif>
			<cfelse>
				<!--- <cfthrow message="cached load:#structKeyExists(cachedObject,'load')#"> --->
				<!--- <cfset LOCAL.variablesTemp = LOCAL.cachedObject.getVariablesScope()>
				<cfset LOCAL.thisTemp = LOCAL.cachedObject.getThisScope()> --->
				<cfset structAppend(VARIABLES,LOCAL.cachedObject.getVariablesScope(),true) />
				<cfset structAppend(this,LOCAL.cachedObject.getThisScope(),true) />
				<!--- <cfthrow message="id: #(structKeyList(LOCAL.variablesTemp))#"> --->
			</cfif>
		</cfif>

		<!--- INTERCEPTOR: aferSynapseLoad --->
		<cfset this.afterSynapseLoad()>
		<cfreturn this>
	</cffunction>
	
	<cffunction name="save" access="public" returntype="Any" output="false" hint="I persist the classes current values to the database by calling either create or update as needed">
		<cfargument name="persistChildren" required="false" type="boolean" hint="I indicate whether children entities should also be persisted on a save">
		<cfargument name="persistSiblings" required="false" type="boolean" hint="I indicate whether sibling entities should also be persisted on a save">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.persistChildren = true>
		<cfset LOCAL.persistSiblings = true>
		<cfset LOCAL.recordExists = false>
		
		<cfif structKeyExists(ARGUMENTS,'persistChildren')>
			<cfset LOCAL.persistChildren = ARGUMENTS.persistChildren>
		</cfif>
		
		<cfif structKeyExists(ARGUMENTS,'persistSiblings')>
			<cfset LOCAL.persistSiblings = ARGUMENTS.persistSiblings>
		</cfif>
		
		<!--- CHECK IF RECORD EXISTS --->
		<cfset LOCAL.recordExists = this.recordExists(getPKName(),getPKValue())>
		
		<!--- INTERCEPTOR: beforeSynapseSave --->		
		<cfif this.beforeSynapseSave() EQ true>
			<!--- CHECK IF ITS A NEW SAVE OR AN UPDATE --->
			<cfif NOT LOCAL.recordExists>
				
				<cfif getPKType() EQ 'auto-uuid' AND len(this.getPKValue()) EQ 0>
					<cfset evaluate('this.set#getPKName()#("#generateID()#")')>
				<!--- <cfelseif getPKType() EQ 'auto-increment'>
					<cfset structDelete(this,getPKName())> --->
				</cfif>
				
				<cfset create()>
			<cfelse>
				<cfset update()>
			</cfif>

			<!--- SET PERSISTENCE STATUS --->
			<cfset VARIABLES.class.tsPersistence()>
			<!--- persist children --->
			<cfif LOCAL.persistChildren>
				<cfset this.persistChildren()>
			</cfif>
			<cfset this.isPersisted(true)>
			
			<!--- CACHE --->
			<cfif this.useCache()>
				<cfset LOCAL.cacheKey = '#this.getAlias()#_#this.getPKValue()#'>
				<cfset cacheRemove(LOCAL.cacheKey)>
				<cfset cachePut(cacheKey,this)>
			</cfif>

			<!--- INTERCEPTOR: aferSynapseSaveTransaction --->
			<cfset this.afterSynapseSaveTransaction()>
			
			<!--- persist for siblings in the linking table --->
			<cfif LOCAL.persistSiblings>
				<cfset LOCAL.persistedSiblingLinks = persistSiblingLinks()>
			</cfif>
		</cfif>

		<!--- INTERCEPTOR: aferSynapseSave --->
		<cfset this.afterSynapseSave()>
		<cfreturn this>
	</cffunction>
	
	<cffunction name="create" access="public" returntype="boolean" output="false" hint="I save a new record to the database">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		<!--- GET ARRAY OF PROPERTIES IN THIS CLASS --->
		<cfset LOCAL.arrProperties = this.getProperties()>
		
		<!--- REMOVE THE PK IF ITS AN AUTO-INCREMENT --->
		<cfif getPKType() EQ 'auto-increment'>
			<cfset arrayDelete(LOCAL.arrProperties,getPKName())>
		</cfif>
		<!--- MAKE ARRAY INTO ITERATOR --->
		<cfset LOCAL.iProperty = LOCAL.arrProperties.iterator()>
		
		<cfset LOCAL.cols = ''>
		<cfset LOCAL.values = 'VALUES ('>
		<cfset LOCAL.update = ''>
		
		<!--- INTERCEPTOR: beforeSynapseCreate --->
		<cfset LOCAL.result =  this.beforeSynapseCreate()>
		<cfif LOCAL.result EQ true>
			<!--- DO QUERY --->
			<cfquery datasource="#this.getDSN()#" name="qSave">
				<cfsavecontent variable="saveQuery">
				<!--- BUILD UP NEEDED SQL LINES --->
				<cfloop condition="#LOCAL.iProperty.hasNext()#">
					<cfset curProp = LOCAL.iProperty.next()>
					<cfset LOCAL.oProperty = getProperty(curProp)>
					<cfset LOCAL.curPropValue = VARIABLES[curProp]>
					
					<cfif NOT (curProp EQ '' AND (LOCAL.curPropValue EQ '' OR isNull(LOCAL.curPropValue)) AND LOCAL.oProperty.isNullable())>
						<cfsavecontent variable="theVal"><cfqueryparam value="#VARIABLES[curProp]#" cfsqltype="#this.getQueryParamType(curProp)#"></cfsavecontent>
						<!--- cols --->
						<cfset LOCAL.cols = LOCAL.cols&colWrapper(curProp)>	
						<cfif LOCAL.iProperty.hasNext()><cfset LOCAL.cols = LOCAL.cols&','><cfelse><cfset LOCAL.cols = LOCAL.cols> </cfif>
						<!--- values --->
						<cfset LOCAL.values = LOCAL.values&theVal>
						<cfif LOCAL.iProperty.hasNext()> <cfset LOCAL.values = LOCAL.values&','> <cfelse> <cfset LOCAL.values = LOCAL.values&')'> </cfif>
						<!--- update --->
						<!--- <cfset update = update&curProp&' = ('&theVal&')'> 
						<cfif iProperty.hasNext()><cfset update = update&','></cfif> --->
					</cfif>
				</cfloop>
				INSERT INTO #this.getTable()#
				(#LOCAL.cols#)
				#LOCAL.values#
				<!--- ON DUPLICATE KEY UPDATE
				#update# --->
				</cfsavecontent>
				#preserveSingleQuotes(saveQuery)#
			</cfquery>	
			
			<!--- INTERCEPTOR: aferSynapseCreateTransaction --->
			<cfset LOCAL.result = this.afterSynapseCreateTransaction()>
		</cfif>
		
		<!--- INTERCEPTOR: aferSynapseCreate --->
		<cfset LOCAL.result = this.afterSynapseCreate()>

		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="update" access="public" returntype="boolean" output="false" hint="I update an existing record in the database">
		<cfset var LOCAL = structNew()>
		<cfset var curProp = ''>
		<cfset LOCAL.result = false>
		
		<!--- GET ARRAY OF PROPERTIES IN THIS CLASS --->
		<cfset LOCAL.arrProperties = this.getProperties()>
		
		<!--- REMOVE THE PK IF ITS AN AUTO-INCREMENT --->
		<cfif getPKType() EQ 'auto-increment'>
			<cfset arrayDelete(LOCAL.arrProperties,getPKName())>
		</cfif>
		<!--- MAKE ARRAY INTO ITERATOR --->
		<cfset LOCAL.iProperty = LOCAL.arrProperties.iterator()>
		
		<cfset LOCAL.update = ''>
		
		<cfset LOCAL.propCount = 0>
		<!--- INTERCEPTOR: beforeSynapseCreate --->
		<cfset LOCAL.result = this.beforeSynapseUpdate()>
		<cfif LOCAL.result EQ true>
			<!--- DO QUERY --->
			<cfquery datasource="#this.getDSN()#" name="qSave">
				<cfsavecontent variable="saveQuery">
				<!--- BUILD UP NEEDED SQL LINES --->
				<cfloop condition="#LOCAL.iProperty.hasNext()#">
					<cfset curProp = LOCAL.iProperty.next()>
					<cfset LOCAL.oProperty = getProperty(curProp)>
					<cfset LOCAL.curPropValue = VARIABLES[curProp]>
					
					<cfif NOT LOCAL.oProperty.ignoreOnUpdate() AND NOT (curProp EQ '' AND (LOCAL.curPropValue EQ '' OR isNull(LOCAL.curPropValue)) AND LOCAL.oProperty.isNullable())>
						<!--- <cfif FALSE> --->
						
						<cfset LOCAL.propCount = LOCAL.propCount+1>
						<cfsavecontent variable="theVal"><cfqueryparam value="#LOCAL.curPropValue#" cfsqltype="#this.getQueryParamType(curProp)#"></cfsavecontent>
						<!--- update --->
						<cfset LOCAL.update = LOCAL.update&colWrapper(curProp)&' = ('&theVal&')'> 
						<cfif LOCAL.iProperty.hasNext()><cfset LOCAL.update = LOCAL.update&','></cfif>
					</cfif>
				</cfloop>
				UPDATE #this.getTable()#
				SET #LOCAL.update#
				WHERE #colWrapper(this.getPKName())# = <cfqueryparam cfsqltype="#this.getQueryParamType(this.getPKName())#" value="#this.getPKValue()#">
				</cfsavecontent>
				<!--- <cfthrow message="#javaCast('string',LOCAL.propCount)#"> --->
				<cfif LOCAL.propCount GT 0>
				#saveQuery#
				<cfelse>
				<!--- SELECT `#this.getPKName()#` FROM #this.getTable()# LIMIT 1 --->
				</cfif>
			</cfquery>
			<!--- <cfthrow message="update complete"> --->
			<!--- INTERCEPTOR: aferSynapseUpdateTransaction --->
			<cfset LOCAL.result = this.afterSynapseUpdateTransaction()>
		</cfif>
		
		<!--- persist for siblings in the linking table --->	
		<!--- NOW DONE IN SAVE() <cfset persistedSiblingLinks = persistSiblingLinks()> --->
		
		<!--- INTERCEPTOR: aferSynapseUpdate --->
		<cfset LOCAL.result = this.afterSynapseUpdate()>

		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="persistChildren" access="public" returntype="Any" output="false" hint="I persist the children classes current values to the database by calling either create or update as needed">
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.children = VARIABLES.class.getChildren()>
		
		<cfloop collection="#LOCAL.children#" item="c">
			<cfset arrChildrenGroup = getChildren(c)>
			<cfloop array="#arrChildrenGroup#" index="g">
				<cfif NOT g.isPersisted()>
					<cfset g.save()>
				</cfif>
			</cfloop>
		</cfloop>
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="delete" access="public" returntype="boolean" output="false" hint="I delete the current active record as well as related children and many-to-many links">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		<!--- INTERCEPTOR: beforeSynapseDelete --->
		<cfset LOCAL.result = this.beforeSynapseDelete()>
		<cfif LOCAL.result EQ true>
			<!--- DELETE CHILDREN --->
			<cfloop collection="#VARIABLES.class.getChildren()#" item="c">
				<cfset deleteChildren(c)>
			</cfloop>
			
			<!--- DELETE SIBLING LINKS --->
			<cfloop collection="#VARIABLES.class.getSiblings()#" item="s">
				<cfset deleteSiblingLinks(s)>
			</cfloop>
		
		
			<!--- DO QUERY --->
			<cfquery datasource="#this.getDSN()#" name="qSave">
				DELETE FROM #this.getTable()#
				WHERE #colWrapper(getPKName())# = <cfqueryparam cfsqltype="#this.getQueryParamType(getPKName())#" value="#this.getPKValue()#">
			</cfquery>
			
			<!--- INTERCEPTOR: aferSynapseDeleteTransaction --->
			<cfset LOCAL.result = this.afterSynapseDeleteTransaction()>
			
			<!--- REMOVE CACHE --->
			<cfif this.cache()>
				<cfset LOCAL.cacheKey = "#getAlias()#_#getPKValue()#">
				<cfset cacheRemove(LOCAL.cacheKey)>
			</cfif>
		
		</cfif>
		
		<!--- INTERCEPTOR: aferSynapseDelete --->
		<cfset LOCAL.result = this.afterSynapseDelete()>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="persistSiblingLinks" access="public" returntype="boolean" output="false" hint="I update link tables to siblings">
		<cfset var LOCAL = structNew()>
		<cfset var f = ''>
		<cfset LOCAL.siblings = VARIABLES.class.getSiblings()>
		
		<!--- CHECK IF HAS SIBLINGS --->
		<cfif structCount(LOCAL.siblings) GTE 1>
			<cfloop collection="#LOCAL.siblings#" item="s">
			<cfif LOCAL.siblings[s].getType() EQ 'many-to-many'>
				<!--- name of link table --->
				<cfset LOCAL.linkTable = LOCAL.siblings[s].getLinkTable()>
				<!--- name of the sibling alias --->
				<cfset LOCAL.siblingClass = LOCAL.siblings[s].getORMClass()>
				<cfset LOCAL.siblingAlias = LOCAL.siblingClass.getAlias()>
				<!--- foreign key name (for this class type) --->
				<cfset LOCAL.fkname = LOCAL.siblings[s].getForeignKeyName()>
				<!--- foreign key as it would be in link table (for sibling class type) --->
				<cfset LOCAL.linkfkname = LOCAL.siblings[s].getLinkForeignKeyName()>
				<!--- list of keys to be siblings --->
				<cfset LOCAL.fkeys = listSort(evaluate("this.get#LOCAL.linkfkname#()"),"text")>

				<!--- list of current keys --->
				<cfset LOCAL.qCurSiblings = this.getSiblingsAsQuery(LOCAL.siblingAlias)>
				<cfset LOCAL.siblingPKName = LOCAL.siblings[s].getORMClass().getPKName()>
				<cfset LOCAL.curSiblingKeys = listSort(valueList("LOCAL.qCurSiblings['#LOCAL.siblingPKName#']"),"text")>
			
				<!--- get difference of CurSiblingKeys with respect to FKeys  --->
				<cfset LOCAL.keyDiff = ''>
				<cfset LOCAL.keyNew = LOCAL.fkeys>
				<cfloop list="#LOCAL.curSiblingKeys#" index="f">
					<cfset LOCAL.keyLocation = listContainsNoCase(fkeys,f)>
					<cfif LOCAL.keyLocation EQ 0>
					    <!--- if in current keys(fkeys) and not in supplied keys(curSiblingKeys), add id to keyDiff --->
					    <cfset LOCAL.keyDiff = listAppend(LOCAL.keyDiff,f)>
					    <!--- and remove from keyNew --->
					    <cfif LOCAL.keyLocation GT 0>
							<cfset LOCAL.keyNew = listDeleteAt(keyNew,LOCAL.keyLocation)>
						</cfif>
					</cfif>
				</cfloop>

				<!--- DELETE CURRENT RECORD FROM JOINING TABLE--->
					<cfquery datasource="#this.getDSN()#" name="qDeleteSiblings">
					DELETE FROM #LOCAL.linkTable#
					WHERE 1=0
					<!--- loop through rows not siblings anymore (keyDiff) --->
					<cfif listLen(LOCAL.keyDiff) GT 0>
						<cfloop list="#LOCAL.keyDiff#" index="f">
						OR 
						#colWrapper(LOCAL.fkname)# = <cfqueryparam value="#this.getPKValue()#" cfsqltype="#this.getQueryParamType(this.getPKName())#">
						AND #colWrapper(LOCAL.linkfkname)# = <cfqueryparam value="#f#" cfsqltype="#this.getQueryParamType(LOCAL.siblingClass.getPKName())#">
						</cfloop>
					<cfelseif listLen(LOCAL.fkeys) GT 0 AND LOCAL.fkeys NEQ LOCAL.keyNew>
						OR
						<!--- or indicated that no more links to sibling s --->
						#colWrapper(LOCAL.fkname)# = <cfqueryparam value="#this.getPKValue()#" cfsqltype="#this.getQueryParamType(this.getPKName())#">
					</cfif>
					</cfquery>

					<!--- if the bean has been populated with some --->
					<cfif structKeyExists(LOCAL,'fkeys')>
						<cfset doLog("siblingpersist fkeys #LOCAL.fkeys#")>
						<!--- UPDATE CURRENT RECORD TO JOINING TABLE WITH --->
						<cfloop list="#LOCAL.fkeys#" index="f">
							<cfif NOT this.isSibling(LOCAL.siblingAlias,trim(f))>
								<cfquery datasource="#this.getDSN()#" name="qInsertSiblings">
								INSERT INTO #LOCAL.linktable#
								(#colWrapper(LOCAL.fkname)#,#colWrapper(LOCAL.linkfkname)#)
								VALUES ('#this.getPKValue()#','#f#')
								</cfquery>
							</cfif>
						</cfloop>
					</cfif>
				</cfif>
			</cfloop>
		</cfif>
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="deleteChildren" access="public" returntype="boolean" output="false" hint="I delete the children(defined in alias argument) of this record">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getChildren()[LOCAL.alias]>
		<cfset LOCAL.child = LOCAL.link.getORMClass()>
		<cfset LOCAL.table = LOCAL.child.getTable()>
		<cfset LOCAL.fkname = LOCAL.link.getForeignKeyName()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		
		<cfif LOCAL.child.hasDecorator()>
			<!--- get siblings --->
			<cfset LOCAL.children = getChildren(LOCAL.alias)>
			
			<!--- loop through and delete --->
			<cfloop array="#LOCAL.children#" index="c">
				<cfset c.delete()>
			</cfloop>
		<cfelse>
			<cfquery name="qChildren" datasource="#this.getDSN()#">
				DELETE FROM #LOCAL.table#
				WHERE #colWrapper(LOCAL.fkname)# = <cfqueryparam cfsqltype="#LOCAL.child.getQueryParamType(LOCAL.fkname)#" value="#this.getPKValue()#">
			</cfquery>
		</cfif>
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="deleteSiblings" access="public" returntype="Boolean" output="false" hint="I delete the siblings(defined in alias argument) of this record">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getSiblings()[LOCAL.alias]>
		<cfset LOCAL.sibling = LOCAL.link.getORMClass()>
		<cfset LOCAL.table = LOCAL.sibling.getTable()>
		<cfset LOCAL.fkname = LOCAL.link.getForeignKeyName()>
		<cfset LOCAL.linktable = LOCAL.link.getLinkTable()>
		<cfset LOCAL.linkfkname = LOCAL.link.getLinkForeignKeyName()>
		<cfset LOCAL.arrResult = arrayNew(1)>
		<!--- delete the links --->
		<cfquery name="qSiblings" datasource="#this.getDSN()#">
			DELETE FROM #LOCAL.table#
			WHERE #colWrapper(LOCAL.sibling.getPKName())# IN (
											SELECT #colWrapper(LOCAL.linkfkname)#
											FROM #LOCAL.linktable#
											WHERE #colWrapper(LOCAL.linkfkname)# = <cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(this.getPKName())#" value="#this.getPKValue()#">
											)
		</cfquery>
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="deleteSiblingLinks" access="public" returntype="Boolean" output="false" hint="I delete the siblings(defined in alias argument) links of this record">
		<cfargument name="alias" required="true" type="String" hint="I am the alias used to reference the class">
		
		<cfset var LOCAL = structNew()>
		
		<!--- <cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getSiblings()[LOCAL.alias]>
		<cfset LOCAL.sibling = LOCAL.link.getORMClass()>
		<cfset LOCAL.linktable = LOCAL.link.getLinkTable()>
		<cfset LOCAL.linkfkname = LOCAL.link.getLinkForeignKeyName()>
		
		<cfquery name="qSiblingLink" datasource="#this.getDSN()#">
			DELETE FROM #LOCAL.linktable#
			WHERE #LOCAL.linkfkname# = <cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(this.getPKName())#" value="#this.getPKValue()#">
		</cfquery> --->
		<cfset LOCAL.alias = ARGUMENTS.alias>
		<cfset LOCAL.link = VARIABLES.class.getSiblings()[LOCAL.alias]>
		<cfset LOCAL.fkname = LOCAL.link.getForeignKeyName()>
		<cfset LOCAL.linkfkname = LOCAL.link.getLinkForeignKeyName()>
		<cfset LOCAL.fkeys = evaluate("this.get#LOCAL.linkfkname#()")>
		<cfset LOCAL.linkTable = VARIABLES.class.getSiblings()[s].getLinkTable()>
		
		<cfif LOCAL.link.getType() EQ 'many-to-many'>
			
			<!--- DELETE CURRENT RECORD FROM JOINING TABLE--->
			<cfquery datasource="#this.getDSN()#" name="qDeleteSiblings">
			DELETE FROM #LOCAL.linkTable#
			WHERE #colWrapper(LOCAL.fkname)# = <cfqueryparam value="#this.getPKValue()#" cfsqltype="#this.getQueryParamType(this.getPKName())#">
			</cfquery>
		</cfif>
		
		<cfreturn true>
	</cffunction>
	
	<!--- MANIPULATION and DECISION --->
	
	<cffunction name="isChild" access="public" output="false" returntype="Boolean" hint="I return a boolean indicating if a record is a child of this bean">
		<cfargument name="value" required="true" type="Any" hint="I am the simple value for the stipulated child primary key or the SynapseBean">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		
		<cfset LOCAL.value = ARGUMENTS.value>
		<!--- IF IS SIMPLE VALUE, ALIAS MUST EXIST --->
		<cfif isSimpleValue(ARGUMENT.value)>
			<cfset LOCAL.alias = ARGUMENTS.alias>
			<cfset LOCAL.child = VARIABLES.class.getChildren()[LOCAL.alias].getBean().load(LOCAL.value)>
		<!--- IF SynapseBean --->
		<cfelseif isInstanceOf(LOCAL.value,"synapse.SynapseBean")>
			<cfset LOCAL.alias = LOCAL.value.getAlias()>
			<cfset LOCAL.child = ARGUMENTS.value>
		</cfif>
		
		<cfset LOCAL.parent = LOCAL.child.getParent(getAlias())>
		
		<cfif LOCAL.parent.getPKValue EQ this.getPKValue()>
			<cfset LOCAL.result = true>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="isSibling" access="public" output="false" returntype="Boolean" hint="I return a boolean indicating if a record exists for this entity type based on the given alias/value pair">
		<cfargument name="alias" required="false" type="String" hint="I am the alias used to reference the class">
		<cfargument name="value" required="true" type="Any" hint="I am the simple value for the stipulated sibling primary key or the SynapseBean">
		
		<cfset var LOCAL = structNew()>
		<cfset var qSiblings = "">
		<cfset LOCAL.result = false>
		<cftry>
			<cfset LOCAL.value = ARGUMENTS.value>
			<!--- IF IS SIMPLE VALUE, ALIAS MUST EXIST --->
			<cfif isSimpleValue(LOCAL.value)>
				<cfset LOCAL.alias = ARGUMENTS.alias>
				<cfset LOCAL.sibling = this.getClass().getSiblings()[LOCAL.alias].getORMClass().getBean().load(LOCAL.value)>
			<!--- IF SynapseBean --->
			<cfelseif isInstanceOf(LOCAL.value,"synapse.SynapseBean")>
				<cfset LOCAL.alias = LOCAL.value.getAlias()>
				<cfset LOCAL.sibling = ARGUMENTS.value>
				<cfset LOCAL.value = ARGUMENTS.value>
			</cfif>
			
			<cfset qSiblings = getSiblingsAsQuery(LOCAL.alias)>
			
			<cfquery name="LOCAL.qSiblingCount" dbtype="query">
				SELECT COUNT(#LOCAL.sibling.getPKName()#) AS siblingcount
				FROM qSiblings
				WHERE #LOCAL.sibling.getPKName()# = <cfqueryparam cfsqltype="#LOCAL.sibling.getQueryParamType(LOCAL.sibling.getPKName())#" value="#LOCAL.sibling.getPKValue()#">
			</cfquery>
			
			<cfif LOCAL.qSiblingCount.siblingcount GT 0>
				<cfset LOCAL.result = true>
			</cfif>
		<cfcatch type="any">
			<cfrethrow>
			<cfif structKeyExists(ARGUMENTS,'alias')>
				<cfset LOCAL.errorMessage = "sibling: #LOCAL.alias#">
			</cfif>
			<cfthrow message="this: #this.getAlias()# -> #LOCAL.errorMessage#: #cfcatch.message#">
		</cfcatch>
		</cftry>
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="recordExists" access="public" output="false" returntype="Boolean" hint="I return a boolean indicating if a record exists for this entity type based on the given property/value pair">
		<cfargument name="property" required="true" type="String" hint="I am a property of this entity, matching a column in the mapped table">
		<cfargument name="value" required="true" type="Any" hint="I am the value for the stipulated property">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.dsn = this.getDSN()>
		<cfset LOCAL.pkname = getPKName()>
		<cfset LOCAL.result = false>
		
		<cfquery name="qCount" datasource="#getDSN()#">
		SELECT COUNT(#ARGUMENTS.property#) AS myCount
		FROM #this.getTable()#
		WHERE #colWrapper(ARGUMENTS.property)# = <cfqueryparam cfsqltype="#this.getQueryParamType(ARGUMENTS.property)#" value="#ARGUMENTS.value#">
		</cfquery>
		
		<cfif qCount.myCount GT 0>
			<cfset LOCAL.result = true>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>

	<cffunction name="isPropertyRequired"  access="public" returntype="boolean" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		
		<cfreturn VARIABLES.class.isPropertyRequired(ARGUMENTS.property)>
	</cffunction>

	<cffunction name="isPropertyParentKey"  access="public" returntype="boolean" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		
		<cfset LOCAL.result = VARIABLES.class.isPropertyParentKey(ARGUMENTS.property)>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="getPropertyParentAlias"  access="public" returntype="String" output="false" hint="I return whether the property is required">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the required indicator is returned">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = ''>
		
		<cfset LOCAL.result = VARIABLES.class.getPropertyParentAlias(ARGUMENTS.property)>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="hasSibling"  access="public" returntype="boolean" output="false" hint="I return whether the property is required">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		
		<cfset LOCAL.result = VARIABLES.class.hasSibling()>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="getSiblingLinks"  access="public" returntype="Struct" output="false" hint="I return whether the property is required">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = structNew()>
		
		<cfset LOCAL.result = VARIABLES.class.getSiblings()>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<!--- UTILITY --->
	<cffunction name="getPersistedValues"  access="public" returntype="Struct" output="false" hint="I return the values of this bean as they are currently persisted ie. will differ if properties have been set since last save">
		<cfset var LOCAL.result = structNew()>
		<cfset var qSelect = ''>
		<cfset LOCAL.iterator = getProperties().iterator()>
		<cfquery datasource="#this.getDSN()#" name="qSelect" >
			<cfsavecontent variable="LOCAL.queryStatement">
			<cfoutput>
			SELECT 
			<cfloop condition="#LOCAL.iterator.hasNext()#">
				<cfoutput>#colWrapper(LOCAL.iterator.next())#<cfif LOCAL.iterator.hasNext()>,</cfif></cfoutput>
			</cfloop>
			FROM #getTable()#
			WHERE #colWrapper(this.getPKName())# = <cfqueryparam cfsqltype="#this.getQueryParamType(this.getPKName())#" value="#this.getPKValue()#">
			</cfoutput>
			</cfsavecontent>
			<cfoutput>#LOCAL.queryStatement#</cfoutput>
		</cfquery>
		<cfif queryCount(qSelect) EQ 1>
		<cfloop array="#this.getProperties()#" index="p">
			<cfset LOCAL.result[p] = qSelect[p]>
		</cfloop>
		</cfif>
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="getDefaultDisplayProperty"  access="public" returntype="String" output="false" hint="I return this classes alias">
		<cfreturn VARIABLES.class.getDefaultDisplayProperty()>
	</cffunction>
	
	<cffunction name="getDefaultDisplayValue"  access="public" returntype="String" output="false" hint="I return this classes alias">
		<cfset var displayProperty = this.getDefaultDisplayProperty()>
		<cfreturn  evaluate('this.get#displayProperty#()')>
	</cffunction>
	
	<cffunction name="decorate" access="public" returntype="void" output="false" hint="I mix one object into another as a variable">
		<cfargument name="decorator" required="true" type="Any" hint="I am the Object to decorate SynapseBean with">
		<cfargument name="useExtends" required="true" type="Boolean" default="true" hint="I indicate whether to use object that decorator extends as well">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.mixinMeta=getMetaData(ARGUMENTS.decorator)>
		<!--- FUNCTIONS EXTENDED BY DECORATOR --->
		<cfif structKeyExists(LOCAL.mixinMeta,'extends')>
			<cfif structKeyExists(LOCAL.mixinMeta.extends,'functions')>
				<cfloop array="#LOCAL.mixinMeta.extends.functions#" index="f">
					<cfset LOCAL.functionName = f.name>
					<cfset THIS[f.name] = ARGUMENTS.decorator[f.name]>
				</cfloop>
			</cfif>
		</cfif>
		
		<!--- FUNCTIONS IN DECORATOR --->
		<cfif structKeyExists(LOCAL.mixinMeta,'functions')>
			<cfloop array="#LOCAL.mixinMeta.functions#" index="f">
				<cfset LOCAL.functionName = f.name>
				<cfset THIS[f.name] = ARGUMENTS.decorator[f.name]>
			</cfloop>
		</cfif>
		
	</cffunction>
	
	<cffunction name="interceptor" access="public" returntype="void" output="false" hint="I set the interceptor for the bean">
		<cfargument name="interceptor" required="true" type="synapse.SynapseInterceptor" hint="Object to set as interceptor of type SynapseInterceptor">
		<cfset VARIABLES.interceptor = ARGUMENTS.interceptor>
		<cfset VARIABLES.interceptor.configure()>
	</cffunction>
	
	<cffunction name="iterator" access="public" returntype="synapse.SynapseListIterator" output="false" hint="I return the iterator of collection past in">
		<cfargument name="collection" required="true" type="Any" hint="I am the collection to return as an iterator">
		<cfargument name="class" required="true" type="synapse.SynapseClass">
		
		<cfset var LOCAL = structNew()>
		<cfreturn createObject("component",'synapse.SynapseListIterator').init(ARGUMENTS.collection,ARGUMENTS.class)>
	</cffunction>
	
	<cffunction name="getPKName" access="public" returntype="String" output="false" hint="I return the name of this classes primary key">
		<cfreturn VARIABLES.class.getPKName()>
	</cffunction>
	
	<cffunction name="getPKValue" access="public" returntype="String" output="false" hint="I return the value of this classes primary key">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.id = evaluate('this.get#getPKName()#()')>
		<cfreturn LOCAL.id>
	</cffunction>
	
	<cffunction name="getPKValueByProperty" access="private" returntype="Any" output="false" hint="I return the PK as determined by the property value pair">
		<cfargument name="property" type="any" required="false" hint="Used with value argument to get a object with a property with a specific value">
		<cfargument name="value" type="string" required="false" hint="Used with property argument to get a object with a property with a specific value">
		
		<cfset var LOCAL = structNew()>
		<cfset  var qSelect = ''>
		<!--- OTHER VARIABLES --->
		<cfset LOCAL.tempStruct = structNew()>
		<cfset LOCAL.queryStatement = ''>
		<cfset LOCAL.dsn = getDSN()>
		<cfset LOCAL.pkname = getPKName()>
	
		<cfquery datasource="#LOCAL.dsn#" name="qSelect" >
			<cfsavecontent variable="LOCAL.queryStatement">
			<cfoutput>
			SELECT #colWrapper(LOCAL.pkname)# AS ID
			FROM #getTable()#
			WHERE 1=1
			<cfif structKeyExists(ARGUMENTS,'property') AND structKeyExists(ARGUMENTS,'value')>
				<!--- by property --->
				AND #colWrapper(ARGUMENTS.property)# = <cfqueryparam cfsqltype="#this.getQueryParamType(LOCAL.pkname)#" value="#ARGUMENTS.value#">
			<cfelseif structKeyExists(ARGUMENTS,'property') AND NOT structKeyExists(ARGUMENTS,'value')>
				<cfif NOT isStruct(ARGUMENTS.property)>
					<cfthrow message="Property map must be supplied">
				</cfif>
				<!--- by property map --->
				<cfloop collection="#ARGUMENTS.property#" item="p">
				AND #colWrapper(p)# =  <cfqueryparam cfsqltype="#this.getQueryParamType(p)#" value="#ARGUMENTS.property[p]#">
				</cfloop>
			<cfelse>
				<!--- VALIDATION --->
				<cfif NOT structKeyExists(ARGUMENTS,"id")>
					<cfthrow message="No ID supplied to retrieve the record.">
				</cfif>
				<!--- by primary key --->
				AND #colWrapper(LOCAL.pkname)# = <cfqueryparam cfsqltype="#this.getQueryParamType(LOCAL.pkname)#" value="#ARGUMENTS.id#">
			</cfif>
		
		<!--- <cfif structKeyExists(ARGUMENTS,'value')>
		WHERE #ARGUMENTS.property# = <cfqueryparam cfsqltype="#this.getQueryParamType(pkname)#" value="#ARGUMENTS.value#">
		<cfelse>
		WHERE #pkname# = <cfqueryparam cfsqltype="#this.getQueryParamType(pkname)#" value="#ARGUMENTS.id#">
		</cfif> --->
		
			</cfoutput>
			</cfsavecontent>
			<cfoutput>#LOCAL.queryStatement#</cfoutput>
		</cfquery>
		
		<cfif queryCount(qSelect) EQ 1>
			<cfset LOCAL.id = qSelect.ID>
		<cfelse>
			<cfset LOCAL.id = ''>
		</cfif>
		
		<cfreturn LOCAL.id>
	</cffunction>
	
	<cffunction name="reset" access="public" returntype="Boolean" output="false" hint="I set all the classes property to a blank string">
		<cfloop array="#this.getProperties()#" index="i">
			<cfset VARIABLES[i] = getProperty(i).getDefaultValue()>
		</cfloop>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="getClass" access="public" returntype="synapse.SynapseClass" output="false" hint="I return the class">
		<cfreturn VARIABLES.class>
	</cffunction>
	
	<cffunction name="getProperty" access="public" returntype="SynapseProperty" output="false" hint="I return the specified property">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property which is returned">

		<cfreturn VARIABLES.class.getProperty(ARGUMENTS.property)>
	</cffunction>
	
	<cffunction name="getPropertyType" access="public" returntype="String" output="false" hint="I return the type of the specified property">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the type is returned">
		
		<cfreturn this.getProperty(ARGUMENTS.property).getType()>
	</cffunction>
	
	<cffunction name="getQueryParamType" access="public" returntype="String" output="false" hint="I get the queryparam type for a specified property">
		<cfargument name="property" required="true" type="String" hint="I am the entities' property for which the query param type is returned">
		
		<cfreturn VARIABLES.class.getQueryParamType(ARGUMENTS.property)>
	</cffunction>
	
	<cffunction name="determineDBType" access="private" returntype="String" output="false" hint="I return the DB type for this classes datasource name">
		<cfreturn VARIABLES.class.determineDBType()>
	</cffunction>
	
	<cffunction name="colWrapper" access="private" returntype="String" output="false" hint="I return a column name with the correct DB column wrapper ie '`' or '[]'">
		<cfargument name="columnName" required="true" type="String" hint="I am the column name">
		<cfreturn VARIABLES.class.colWrapper(ARGUMENTS.columnName)>
	</cffunction>
	
	<cffunction name="getThisScope" access="public" returntype="Any" output="false" hint="I return THIS scope">
		
		<cfreturn THIS>
	</cffunction>
	
	<cffunction name="getVariablesScope" access="public" returntype="Any" output="false" hint="I return VARIABLES scope">
		<cfreturn VARIABLES>
	</cffunction>
	
	<cffunction name="storePrepare" access="private" returntype="Any" output="false" hint="">
		<cfargument name="value" required="true" type="String" hint="I am the value">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.value = ARGUMENTS.value>
		<cfif isDate(LOCAL.value) AND NOT isNumeric(LOCAL.value)>
			<cfset LOCAL.value = '#dateFormat(LOCAL.value,"yyyy-mm-dd")# #timeFormat(LOCAL.value,"HH:mm:ss")#'>
		</cfif>
		<cfreturn LOCAL.value>
	</cffunction>
	
	<cffunction name="queryToStruct" access="private" returntype="any" output="false"
		hint="Converts an entire query or the given record to a struct. This might return a structure (single record) or an array of structures.">
	
		<!--- Define arguments. --->
		<cfargument name="Query" type="query" required="true" />
		<cfargument name="Row" type="numeric" required="false" default="0" />
		
		<cfset var LOCAL = structNew()>
		
		<cfscript>
	
			// Define the local scope.
			var LOCAL = StructNew();
	
			// Determine the indexes that we will need to loop over.
			// To do so, check to see if we are working with a given row,
			// or the whole record set.
			if (ARGUMENTS.Row){
	
				// We are only looping over one row.
				LOCAL.FromIndex = ARGUMENTS.Row;
				LOCAL.ToIndex = ARGUMENTS.Row;
	
			} else {
	
				// We are looping over the entire query.
				LOCAL.FromIndex = 1;
				LOCAL.ToIndex = ARGUMENTS.Query.RecordCount;
	
			}
	
			// Get the list of columns as an array and the column count.
			LOCAL.Columns = ListToArray( ARGUMENTS.Query.ColumnList );
			LOCAL.ColumnCount = ArrayLen( LOCAL.Columns );
	
			// Create an array to keep all the objects.
			LOCAL.DataArray = ArrayNew( 1 );
	
			// Loop over the rows to create a structure for each row.
			for (LOCAL.RowIndex = LOCAL.FromIndex ; LOCAL.RowIndex LTE LOCAL.ToIndex ; LOCAL.RowIndex = (LOCAL.RowIndex + 1)){
	
				// Create a new structure for this row.
				ArrayAppend( LOCAL.DataArray, StructNew() );
	
				// Get the index of the current data array object.
				LOCAL.DataArrayIndex = ArrayLen( LOCAL.DataArray );
	
				// Loop over the columns to set the structure values.
				for (LOCAL.ColumnIndex = 1 ; LOCAL.ColumnIndex LTE LOCAL.ColumnCount ; LOCAL.ColumnIndex = (LOCAL.ColumnIndex + 1)){
	
					// Get the column value.
					LOCAL.ColumnName = LOCAL.Columns[ LOCAL.ColumnIndex ];
	
					// Set column value into the structure.
					LOCAL.DataArray[ LOCAL.DataArrayIndex ][ LOCAL.ColumnName ] = ARGUMENTS.Query[ LOCAL.ColumnName ][ LOCAL.RowIndex ];
	
				}
	
			}
	
	
			// At this point, we have an array of structure objects that
			// represent the rows in the query over the indexes that we
			// wanted to convert. If we did not want to convert a specific
			// record, return the array. If we wanted to convert a single
			// row, then return the just that STRUCTURE, not the array.
			if (ARGUMENTS.Row){
	
				// Return the first array item.
				return( LOCAL.DataArray[ 1 ] );
	
			} else {
	
				// Return the entire array.
				return( LOCAL.DataArray );
	
			}
	
		</cfscript>
	</cffunction>
	
	<cffunction name="queryCount" access="private" returntype="Numeric" hint="I return the number of records in a query in a server (Adove CF vs Railo) agnostic way">
		<cfargument name="myquery" required="true" type="query">
		
		<cfset var LOCAL = structNew()>

		<cfset LOCAL.queryCount = 0>
		<cfif SERVER.coldfusion.productname EQ 'ColdFusion Server'>
			<cfset LOCAL.queryCount = ARGUMENTS.myquery.recordCount>
		<cfelse>
			<cfset LOCAL.queryCount = queryRecordCount(ARGUMENTS.myquery)>
		</cfif>
		<cfreturn LOCAL.queryCount>
	</cffunction>
	
	<cffunction name="doLog" access="private" output="false" returntype="void">
		<cfargument name="label" required="false" default="none">
		
		<!--- log mem --->
		<cfif VARIABLES.class.isMemLogOn()>
			<cfset logMemoryStatus('BEAN/#ARGUMENTS.label#')>
		</cfif>
		
	</cffunction>
	
	<cffunction name="logMemoryStatus" access="private" output="false" returntype="void">
		<cfargument name="label" required="false" default="none">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.label = ''>
		<cfif structKeyExists(ARGUMENTS,'label')>
			<cfset LOCAL.label = ARGUMENTS.label>
		</cfif>
		<cfset LOCAL.filename = "#dateFormat(now(),'yyyy-mm-dd')#.txt">
		<cfset LOCAL.datetime = "#dateFormat(now(),'yyyy-mm-dd')# #timeFormat(now(),'medium')#">
		
		<cfset LOCAL.runTime = createObject("java","java.lang.Runtime").getRuntime()>

		<cfset LOCAL.freeMem = LOCAL.runtime.freememory()/>
		
		<cfset LOCAL.freeMem = int((LOCAL.freeMem/1024)/1024)/>
		
		<cfsavecontent variable="LOCAL.toFile">
			<cfoutput>#LOCAL.datetime#] Free: #LOCAL.freeMem# MB (#LOCAL.label#)</cfoutput>
		</cfsavecontent>
		<cffile action="append" addnewline="true" file="/synapse/log/#LOCAL.filename#" output="#trim(LOCAL.toFile)#">
		
	</cffunction>
	
	<cffunction name="onMissingMethod" access="public" returnType="any" output="false">
		<cfargument name="missingMethodName" type="string" required="true">
		<cfargument name="missingMethodArguments" type="struct" required="true">
		<cfset LOCAL.key = "">
		<cfset LOCAL.value = "">
	
		<!--- AUTO ACCESSOR --->
		<cfif left(ARGUMENTS.missingMethodName,3) IS "get">
			<cfset LOCAL.key = right(ARGUMENTS.missingMethodName, len(ARGUMENTS.missingMethodName)-3)>
			<!--- INTERCEPTOR: beforeSynapseAccess --->
			<cfif structKeyExists(VARIABLES, LOCAL.key) AND this.beforeSynapseAccess(LOCAL.key) EQ true>
				<!--- <cfthrow message="get #LOCAL.key# #VARIABLES[LOCAL.key]#"> --->
				<cfreturn VARIABLES[LOCAL.key]>
				<!--- INTERCEPTOR: afterSynapseAccess --->	
				<cfset this.afterSynapseAccess(LOCAL.key)>
			</cfif>
		</cfif>
		
		<!--- AUTO MUTATOR --->
		<cfif left(ARGUMENTS.missingMethodName,3) IS "set">
			<cfset LOCAL.key = right(ARGUMENTS.missingMethodName, len(ARGUMENTS.missingMethodName)-3)>
			
			<!--- assign value to set --->
			<cfif structCount(ARGUMENTS.missingMethodArguments) EQ 1>
				<cfset LOCAL.value = storePrepare(ARGUMENTS.missingMethodArguments[1])>
			<cfelse>
				<cfset LOCAL.value = storePrepare(ARGUMENTS.missingMethodArguments[LOCAL.key])>
			</cfif>

			<!--- INTERCEPTOR: beforeSynapseMutate --->		
			<cfif this.beforeSynapseMutate(LOCAL.key,LOCAL.value) EQ true>
				
				<cfset VARIABLES[LOCAL.key] = LOCAL.value>
				<!--- INTERCEPTOR: afterSynapseMutate --->	
				<cfset this.afterSynapseMutate(LOCAL.key,LOCAL.value)>
			</cfif>
			
			<cfset VARIABLES.isPersisted = false>

		</cfif>

	</cffunction>
	
	<cffunction name="convertDBToQueryType" access="private" output="false" returntype="String">
			<cfargument name="propertytype" required="true" type="String" hint="I am the entities' property type">
		
		<cfset var LOCAL = structNew()>
		
		<cfset LOCAL.paramType = ''>
		<cfset LOCAL.type = ARGUMENTS.propertytype>
		
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
	
	<!--- Populate a bean from a structure --->
	<cffunction name="populate" access="public" returntype="Boolean" hint="Populate a named or instantiated bean from a structure" output="false" >
		<!--- ************************************************************* --->
		<cfargument name="memento"  required="true" type="struct" 	hint="The structure to populate the object with.">
		<!--- ************************************************************* --->
		<!--- INTERCEPTOR: beforeSynapsePopulate --->	
		<cfif this.beforeSynapsePopulate(ARGUMENTS.memento) EQ true>
			<cfscript>
				var beanInstance = this;
				var key = "";
				
				try{
					/* Populate Bean */
					for(key in ARGUMENTS.memento){
						/* Check if setter exists */
							evaluate("beanInstance.set#key#(ARGUMENTS.memento[key])");
					}
					/* Return if created */
					return true;
				}
				catch(Any e){
					return false;
				}
			</cfscript>
			<!--- INTERCEPTOR: afterSynapsePopulate --->	
			<cfset this.afterSynapsePopulate(ARGUMENTS.memento)>
		</cfif>
		
	</cffunction>
	
	<cffunction name="internalPopulate" access="private" returntype="Boolean" hint="Populate a named or instantiated bean from a structure" output="false" >
		<!--- ************************************************************* --->
		<cfargument name="memento"  required="true" type="struct" 	hint="The structure to populate the object with.">
		<!--- ************************************************************* --->

		<cfscript>
			var beanInstance = this;
			var key = "";
			
			try{
				/* Populate Bean */
				for(key in ARGUMENTS.memento){
					/* Check if setter exists */
						evaluate("beanInstance.set#key#(ARGUMENTS.memento[key])");
				}
				/* Return if created */
				return true;
			}
			catch(Any e){
				return false;
			}
		</cfscript>
		
	</cffunction>
</cfcomponent>