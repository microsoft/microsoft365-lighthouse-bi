# Microsoft 365 Lighthouse Business Intelligence

Through this solution partners are able to consume responses from various Microsoft APIs that have been invoked against their customers in Power BI. Which will enable the ability to gain insights into the current configurations for their customer's Microsoft 365 estate. Also, the functionality required to perform pre-sales assessments will be available.

## Preview

We are excited to share an early preview of this data connector for Power BI. Initially you will need to perform the following actions to utilize this connector

1. Create an Azure Active Directory application and configure it for this connector
2. Update the identifier in the *client_id* file to match the application identifier for your Azure Active Directory application
3. Compile the connector using the *Power Query* extension for Visual Studio
4. Copy the compiled extension file into the `[Documents]\Power BI Desktop\Custom Connectors` directory

In the near future we will be simplifying this process, but for now the above steps are required.
