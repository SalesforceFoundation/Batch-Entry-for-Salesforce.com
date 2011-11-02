/*
Copyright (c) 2011, salesforce.com foundation, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
    * Neither the name of the salesforce.com foundation. nor the names of its contributors 
    may be used to endorse or promote products derived from this software 
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.

*/
/**
* @author Team Kick Ass; Veronica Waters, Evan Callahan, Derek Dsouza, Mike Fullmore
* @date 04/27/2011
* @description base class for the bulk data entry, supports all the custom settings you might have.
*/

public class BulkDataEntry {

	private BulkDataEntry__c bulkCustomSetting;
	private List<BulkDataEntry__c> bulkDataEntryList;
	private String objectName;
	private List<String> entryFieldList;
	private List<String> listFieldList;	
	private Boolean saveBatch;
	private String statusMessage;
	private String batchLookupFieldName;
	private Set<String> fieldSet;
	private String queryString;	
	
	private final String SUCCESS = 'Success';
	private final String FAIL = 'Failure: ';
	private final String CREATED_CUSTOM_SETTING = 'You did not have a default custom setting so we are passing one to you in memory';
	private final String DEFAULT_NAME = 'opportunity';
	private final String DEFAULT_ENTRY_FS = 'AccountID,Name,StageName,Amount,CloseDate';
	private final String DEFAULT_LIST_FS = 'AccountID,Name,StageName,Amount,CloseDate';	
	private final Boolean DEFAULT_SAVE_BATCH = true;
	
	public BulkDataEntry__c getBulkCustomSetting(){return this.bulkCustomSetting;}
	public List<BulkDataEntry__c> getBulkCustomSettingsList(){return this.bulkDataEntryList;}
	public String getObjectName(){return this.objectName;}
	public List<String> getEntryFieldList(){return this.entryFieldList;}
	public List<String> getListFieldList(){return this.listFieldList;}	
	public Boolean getSaveBatch(){return this.saveBatch;}
	public String getStatusMessage(){return this.statusMessage;}
	public String getFailureMessage(){return this.FAIL;}
	public String getBatchLookupFieldName() {return this.batchLookupFieldName;}
	public Set<String> getFieldSet(){return this.fieldSet;}
	public String getQueryString(){return this.queryString;}	
	
	public BulkDataEntry(String pObjectName){
		this.queryString = 'select Id';
		List<BulkDataEntry__c> bulkDataEntryList;
		boolean isValidObject=false;		
		
		try{
			if(pObjectName != null){
				try {
					String s = DescribeHelper.getObjectLabel(pObjectName); 
					isValidObject=true;
				} catch (exception e) {
					isValidObject=false;
					this.statusMessage = this.FAIL + 'You are attempting to perform batch entry on an object that does not exist: ' + pObjectName;
				}
				if(isValidObject) { 	
					this.bulkCustomSetting = BulkDataEntry__c.getValues(pObjectName);
					if(this.bulkCustomSetting==null) {
						this.statusMessage = this.FAIL + 'You do not have a custom setting for the ' + pObjectName+ ' object\'s batch entry. Please enter one.';
						isValidObject=false;
					}
					else {											
						this.statusMessage = this.SUCCESS;
					}
				}				
			} else {
				this.bulkDataEntryList = BulkDataEntry__c.getAll().values();
				/*
				if(bulkDataEntryList != null && bulkDataEntryList.size() > 0){
					this.bulkCustomSetting = bulkDataEntryList[0];
					this.statusMessage = this.SUCCESS;					
				} else {
					insert new BulkDataEntry__c(Name = this.DEFAULT_NAME,
																  Object_Entry_Field_Set__c = this.DEFAULT_ENTRY_FS,
																  Object_List_Field_Set__c = this.DEFAULT_LIST_FS,																  
																  Save_Batch__c = this.DEFAULT_SAVE_BATCH);
																  
					this.statusMessage = this.SUCCESS + this.CREATED_CUSTOM_SETTING;
				}*/
				if(this.bulkDataEntryList == null || this.bulkDataEntryList.isEmpty()) {
					BulkDataEntry__c defaultSetting = new BulkDataEntry__c(Name = this.DEFAULT_NAME,
																  Object_Entry_Field_Set__c = this.DEFAULT_ENTRY_FS,
																  Object_List_Field_Set__c = this.DEFAULT_LIST_FS,																  
																  Save_Batch__c = this.DEFAULT_SAVE_BATCH);
					insert defaultSetting;
					this.bulkDataEntryList = new List<BulkDataEntry__c>();
					this.bulkDataEntryList.add(defaultSetting);																  					
				}
				this.statusMessage = this.SUCCESS + this.CREATED_CUSTOM_SETTING;
			}
						
			if(isValidObject) {
				this.objectName = this.bulkCustomSetting.Name;
				this.saveBatch = this.bulkCustomSetting.Save_Batch__c;
				
				if(this.saveBatch && !checkLookupExists()) { 
					this.statusMessage = this.FAIL + this.objectName + ' does not have a lookup field to the ' + String.valueOf(Batch__c.sObjectType) + ' object. If this is a standard object, you can go to Setup->Customize-><objectname>->Fields to create a lookup field to the Batch. For custom object, please go to Setup->Create->Objects-><objectname> and click \'New\' under the Fields section.';
				} else {
					this.entryFieldList = buildFieldList(this.bulkCustomSetting.Object_Entry_Field_Set__c);
					this.listFieldList = buildFieldList(this.bulkCustomSetting.Object_List_Field_Set__c);					
											
					buildFieldSet();
					buildQueryString();
				}
			}			
		}catch(Exception e){
			this.statusMessage = this.FAIL + e.getMessage();
		}
	}
	
	private List<String> buildFieldList(String pFields){
		List<String> returnList = new List<String>();
		
		if(pFields != null){
			for(String str : pFields.split(',')){
				returnList.add(str);
			}
		}
		return returnList;
	}
	
	private void buildFieldSet(){
		this.fieldSet = new Set<String>();
		
		for(String str : this.entryFieldList){
			this.fieldSet.add(str);
		}
		
		for(String str : this.listFieldList){
			this.fieldSet.add(str);
		}
	}
	
	private void buildQueryString(){
		if(this.fieldSet != null){
			for(String str : this.fieldSet){
				this.queryString += ', ' + str;
			}
		this.queryString += ' from ' + this.objectName + ' '; 
		}
	}
	
	private boolean checkLookupExists() {
		Map<String, Schema.DescribeFieldResult> allFieldsMap = DescribeHelper.getAllFieldsDescribe(this.objectName);
		for(Schema.DescribeFieldResult fr: allFieldsMap.values()) {
			if(fr.getType() == Schema.Displaytype.Reference) {
				Schema.sObjectType parent = fr.getReferenceTo()[0];
				if(parent.getDescribe().getLocalName()==String.valueOf(Batch__c.sObjectType).replace('bde__', '')) {
					batchLookupFieldName = fr.getLocalName();
					return true;
				}
			}
		}
		return false;
	}
	
	static testMethod void testBulkDataEntry(){
		BulkDataEntry__c bulkDataEntrySetting;
		BulkDataEntry bde;
		Set<String> testSet;
		
		bulkDataEntrySetting = new BulkDataEntry__c(Name = 'Contact',
											 Object_Entry_Field_Set__c = 'Test,Field,Set',
											 Object_List_Field_Set__c = 'Test,List,Field,Set',
											 Save_Batch__c = true);
											 
		delete [select id from BulkDataEntry__c];
											 
		//testing before the insert of a record
		bde = new BulkDataEntry(System.now().format());
		System.assert(bde.getStatusMessage().contains('Failure'));
		System.debug('the first failure ' + bde.getStatusMessage());
		
		bde = new BulkDataEntry(null);
		System.assert(bde.getStatusMessage().contains('Success'));
		
		insert bulkDataEntrySetting;
		
		testSet = new Set<String>();
		testSet.add('Test');
		testSet.add('List');
		testSet.add('Field');
		testSet.add('Set');
				
		bde = new BulkDataEntry('Contact');
		bulkDataEntrySetting = bde.getBulkCustomSetting();
		System.assertEquals('Contact', bde.getObjectName());
		System.assertNotEquals(null, bde.getEntryFieldList());
		System.assertNotEquals(null, bde.getListFieldList());		
		System.assert(bde.getSaveBatch());
		System.assertEquals('Success', bde.getStatusMessage());
		System.assert(bde.getFieldSet().contains('Test'));
		System.assertEquals('select Id, Test, Field, Set, List from Contact ', bde.getQueryString());
		/*
		bde = new BulkDataEntry(null);
		bulkDataEntrySetting = bde.getBulkCustomSetting();
		System.assertEquals('Contact', bde.getObjectName());
		System.assertNotEquals(null, bde.getEntryFieldList());
		System.assertNotEquals(null, bde.getListFieldList());
		System.assert(bde.getSaveBatch());
		System.assertEquals('Success', bde.getStatusMessage());
		*/
	}
	
	static testMethod void testBulkDataEntryWithInvalidObject(){
		BulkDataEntry bde = new BulkDataEntry('blah');
											 		
		System.assertEquals('Failure: You are attempting to perform batch entry on an object that does not exist: blah', bde.getStatusMessage());	}
}