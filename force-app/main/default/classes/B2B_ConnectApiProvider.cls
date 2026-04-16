/**
   * @description Interface defining the methods for Connect API operations.
   * This interface allows for mocking and testing of Connect API interactions.
   * It is also implemented by the B2B_ConnectApiProviderMock to simulate same operations
   */
public with sharing class B2B_ConnectApiProvider implements B2B_ConnectApiProvider.ConnectApiInterface {
 
   /**
   * @description : Creates a managed content document with media using the Connect API. It takes in a ManagedContentDocumentInput object containing the metadata for the content and a BinaryInput object containing the actual media data, and returns the created ManagedContentDocument object.
   * @author a.alfath@astounddigital.com | 04-16-2026 
   * @param managedContentInput 
   * @param contentData 
   * @param ; 
   * @return interface 
   **/
   public interface ConnectApiInterface {
    ConnectApi.ManagedContentDocument createManagedContentWithMedia(
      ConnectApi.ManagedContentDocumentInput managedContentInput,
      ConnectApi.BinaryInput contentData
    );
    ConnectApi.ManagedContentPublishOutput publish(
      ConnectApi.ManagedContentPublishInput publishInput
    );

    List<ManagedContent> getManagedContentsByKeys(Set<String> contentKeys);
  }

  /**
  * @description : Implements the createManagedContentWithMedia method defined in the ConnectApiInterface. This method uses the Connect API to create a managed content document with media by passing the provided ManagedContentDocumentInput and BinaryInput parameters to the ConnectApi.ManagedContent.createManagedContentWithMedia method, and returns the resulting ManagedContentDocument object.
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param managedContentInput 
  * @param contentData 
  * @return ConnectApi.ManagedContentDocument 
  **/
  public ConnectApi.ManagedContentDocument createManagedContentWithMedia(
    ConnectApi.ManagedContentDocumentInput managedContentInput,
    ConnectApi.BinaryInput contentData
  ) {
    return ConnectApi.ManagedContent.createManagedContentWithMedia(
      managedContentInput,
      contentData
    );
  }

  /**
  * @description : Implements the publish method defined in the ConnectApiInterface. This method uses the Connect API to publish managed content by passing the provided ManagedContentPublishInput parameter to the ConnectApi.ManagedContent.publish method, and returns the resulting ManagedContentPublishOutput object.
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param publishInput 
  * @return ConnectApi.ManagedContentPublishOutput 
  **/
  public ConnectApi.ManagedContentPublishOutput publish(
    ConnectApi.ManagedContentPublishInput publishInput
  ) {
    return ConnectApi.ManagedContent.publish(publishInput);
  }

  /**
  * @description : Implements the getManagedContentsByKeys method defined in the ConnectApiInterface. This method retrieves a list of ManagedContent records from the database based on a set of content keys. It performs a SOQL query to select the Id, Name, and ContentKey fields from the ManagedContent object where the ContentKey matches any of the values in the provided contentKeys set, and returns the resulting list of ManagedContent records.
  * @author a.alfath@astounddigital.com | 04-16-2026 
  * @param contentKeys 
  * @return List<ManagedContent> 
  **/
  public List<ManagedContent> getManagedContentsByKeys(
    Set<String> contentKeys
  ) {
    return [
      SELECT Id, Name, ContentKey
      FROM ManagedContent
      WHERE ContentKey IN :contentKeys
      WITH SYSTEM_MODE
    ];
  }
}