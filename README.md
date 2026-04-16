This utility classes are designed to help importing bulk images into Salesforce CMS and link them to Products in SF B2B 
based on a specified field or based on SKU by default. The images names should match a specific field values on Products.
Once the products have been linked to images, the flag isProcessed__c will be updated to true - 
In Query we filter the products that were already processed

The are 2 options we can use this utility:

1 - products images are a external server and we have URLs
2- Images are in Static resource or Library

Below, some details on how to use each option

1 - Images are in some server and we have only URLS - For this option we assume there is a field named product_image_Url__c on Product2 object
The images URLs needs to be populated before processing

There is a specific batch B2B_PublicImageToCMSBatchFromURL for this and it has two constructors: 

a - public B2B_PublicImageToCMSBatchFromURL(
    String managedContentSpaceId,
    List<String> productSkus
  ) 

  and
    
b- public B2B_PublicImageToCMSBatchFromURL(
    String managedContentSpaceId)

 Parameters dictionary:
--managedContentSpaceId: Required - the SFID of the CMS Space or the subfolder in CMS -
--productSkuList:  Required for option a - this is if you want to run the logic against a list of specific SKUs

Examples:

B2B_PublicImageToCMSBatchFromURL batchable = new B2B_PublicImageToCMSBatchFromURL('9Pua5000001QZUbCAO');
Database.executeBatch(batchable, 10); 

List<String> productSkuList = new List<String>();
productSkuList.add('dummy-prod-22333');
B2B_PublicImageToCMSBatchFromURL batchable = new B2B_PublicImageToCMSBatchFromURL('9Pua5000001QZUbCAO',productSkuList);
Database.executeBatch(batchable, 10); 


2 - Images are in Static resource or Library:

There is a specific batch for this and it has two constructors: 

a- public B2B_PublicImageToCMSBatch(
    String query,
    String managedContentSpaceId,
    String productSku,
    String field,
    String staticResourceOrLibraryName,
    Boolean isStaticResource
  )

  and

  b - public B2B_PublicImageToCMSBatch(
    String query,
    String managedContentSpaceId,
    String productSku,
    String field
  ) 

parameters dictionary:
--query: Optional - SOQL query if you have a subset of products you want to run the logic on - 
--managedContentSpaceId: Required - the SFID of the CMS Space or the subfolder in CMS -
--productSku:  Optional - this is if you want to run the logic against one specific SKU
--field: Optional - This param represents the field we want to match on, it can take custom field name ex: product_code__c. If not specified, 
the default will be SKU
--staticResourceOrLibraryName: Required - This specifies the name of the static resource or public library where the images are
--isStaticResource: this is just a flag to indicate if the parameter passed is for a static resource or not

--Images are in static resources

B2B_PublicImageToCMSBatch batchable = new B2B_PublicImageToCMSBatch( null, '9Pua5000001QZUbCAO',null,'ProductCode', 'static resource name', true );
Database.executeBatch(batchable, 1); 

-- Images are in Library

B2B_PublicImageToCMSBatch batchable = new B2B_PublicImageToCMSBatch( null, '9Pua5000001QZUbCAO',null,'ProductCode', 'Library name', false );
Database.executeBatch(batchable, 1); 
