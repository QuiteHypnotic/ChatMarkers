# Chat Markers
This project contains the initial prototype of a location based chat application.

## Backend
Node.js is used for the API layer. PostgreSQL is used for location data because of the plugins that allow geospatial queries. Dynamodb is used for all other data.

## Client
The client is an iPhone application that uses APNS to receive messages and a Rest API to access and display data.