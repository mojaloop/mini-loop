#!/usr/bin/env python3

"""
    Fix the .json formatting 
    Fix the comment indenting in the values files for the feat/2352 API updates
    author : Tom Daly 
    Date   : Sept 2022
"""

import fileinput
from operator import sub
import sys
import re
import argparse
from pathlib import Path
from fileinput import FileInput
import fileinput 
import json 

data = None
script_path = Path( __file__ ).absolute()

s1= """
{
      "inputValues": {
    "BASE_CENTRAL_LEDGER_ADMIN": "",
    "CALLBACK_ENDPOINT_BASE_URL": "http://$release_name-ml-testing-toolkit-backend:4040",
    "ENABLE_JWS_SIGNING": true,
    "ENABLE_JWS_VALIDATION": false,
    "ENABLE_PROTECTED_HEADERS_VALIDATION": true,
    "ENABLE_WS_ASSERTIONS": true,
    "HOST_ACCOUNT_LOOKUP_ADMIN": "http://$release_name-account-lookup-service-admin",
    "HOST_ACCOUNT_LOOKUP_SERVICE": "http://$release_name-account-lookup-service",
    "HOST_ACCOUNT_LOOKUP_SERVICE_ADMIN": "http://$release_name-account-lookup-service-admin",
    "HOST_BULK_ADAPTER": "http://$release_name-bulk-api-adapter-service",
    "HOST_CENTRAL_LEDGER": "http://$release_name-centralledger-service",
    "HOST_CENTRAL_SETTLEMENT": "http://$release_name-centralsettlement-service/v2",
    "HOST_LEGACY_SIMULATOR": "http://$release_name-simulator",
    "HOST_ML_API_ADAPTER": "http://$release_name-ml-api-adapter-service",
    "HOST_QUOTING_SERVICE": "http://$release_name-quoting-service",
    "HOST_SIMULATOR": "http://$release_name-simulator",
    "HOST_TRANSACTION_REQUESTS_SERVICE": "http://$release_name-transaction-requests-service",
    "HUB_OPERATOR_BEARER_TOKEN": "NOT_APPLICABLE",
    "PAYEEFSP_BACKEND_TESTAPI_URL": "http://$release_name-sim-$param_simNamePayeefsp-backend:3003",
    "PAYEEFSP_CALLBACK_URL": "http://$release_name-sim-$param_simNamePayeefsp-scheme-adapter:4000",
    "PAYEEFSP_SDK_TESTAPI_URL": "http://$release_name-sim-$param_simNamePayeefsp-scheme-adapter:4002",
    "PAYEEFSP_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-$param_simNamePayeefsp-scheme-adapter:4002",
    "PAYERFSP_BACKEND_TESTAPI_URL": "http://$release_name-sim-$param_simNamePayerfsp-backend:3003",
    "PAYERFSP_CALLBACK_URL": "http://$release_name-sim-$param_simNamePayerfsp-scheme-adapter:4000",
    "PAYERFSP_SDK_TESTAPI_URL": "http://$release_name-sim-$param_simNamePayerfsp-scheme-adapter:4002",
    "PAYERFSP_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-$param_simNamePayerfsp-scheme-adapter:4002",
    "SIMPAYEE_CURRENCY": "USD",
    "SIMPAYEE_JWS_PUB_KEY": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzLtduponsAlAk+3+PQdE\nsgjxRs5qhkrPa0z25NbHvgQYan4bH5GY+nEUX65YN65nusHtCG9gBeU0C56EgZQw\nIpkHDTh166qQGPwdJf5oMlMJn79DSd1I2bghbsNx0a1P6ElH16AyEwvgYtdtMOBW\nNgf7z5/tYgv7bGgmsp3qGlf0nnaux/frJhJ0Hxpd6eUCafwdlrNwc9R6iCKMSxGj\nvVTHgx0D7zSZ/+4PXq6gObyIZoC0uOsKKzlY3USx9khAh+96qfFoNKyfGHltpEPJ\nLmOLh3BtzDuna2KwtNdVNGcjPdCle3b9mNIdhR5aZ/bP6Zm+t9JuRC6ZwU/6WEy3\nFwIDAQAB\n-----END PUBLIC KEY-----\n",
    "SIMPAYEE_MSISDN": "17039811902",
    "SIMPAYEE_NAME": "$param_simNamePayeefsp",
    "SIMPAYER_CURRENCY": "USD",
    "SIMPAYER_MSISDN": "17039811901",
    "SIMPAYER_NAME": "$param_simNamePayerfsp",
    "TESTFSP1_BACKEND_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp1-backend:3003",
    "TESTFSP1_CALLBACK_URL": "http://$release_name-sim-$param_simNameTestfsp1-scheme-adapter:4000",
    "TESTFSP1_SDK_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp1-scheme-adapter:4002",
    "TESTFSP1_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-$param_simNameTestfsp1-scheme-adapter:4002",
    "TESTFSP2_BACKEND_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp2-backend:3003",
    "TESTFSP2_CALLBACK_URL": "http://$release_name-sim-$param_simNameTestfsp2-scheme-adapter:4000",
    "TESTFSP2_SDK_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp2-scheme-adapter:4002",
    "TESTFSP2_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-$param_simNameTestfsp2-scheme-adapter:4002",
    "TESTFSP3_BACKEND_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp3-backend:3003",
    "TESTFSP3_CALLBACK_URL": "http://$release_name-sim-$param_simNameTestfsp3-scheme-adapter:4000",
    "TESTFSP3_SDK_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp3-scheme-adapter:4002",
    "TESTFSP3_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-$param_simNameTestfsp3-scheme-adapter:4002",
    "TESTFSP4_BACKEND_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp4-backend:3003",
    "TESTFSP4_CALLBACK_URL": "http://$release_name-sim-$param_simNameTestfsp4-scheme-adapter:4000",
    "TESTFSP4_SDK_TESTAPI_URL": "http://$release_name-sim-$param_simNameTestfsp4-scheme-adapter:4002",
    "TESTFSP4_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-$param_simNameTestfsp4-scheme-adapter:4002",
    "TEST_NOTIFICATIONS": true,
    "TTKFSP_JWS_KEY": "-----BEGIN PRIVATE KEY-----\n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\nDktFAP1w3ruycnE/t+/H8rDVJGPTHc8=\n-----END PRIVATE KEY-----\n",
    "WS_ASSERTION_TIMEOUT": 5000,
    "accept": "application/vnd.interoperability.parties+json;version=1.1",
    "acceptParties": "application/vnd.interoperability.parties+json;version=1.1",
    "acceptPartiesOld": "application/vnd.interoperability.parties+json;version=1.0",
    "acceptPartiesNotSupported": "application/vnd.interoperability.parties+json;version=2.0",
    "acceptParticipants": "application/vnd.interoperability.participants+json;version=1.1",
    "acceptParticipantsOld": "application/vnd.interoperability.participants+json;version=1.0",
    "acceptParticipantsNotSupported": "application/vnd.interoperability.participants+json;version=2.0",
    "acceptQuotes": "application/vnd.interoperability.quotes+json;version=1.1",
    "acceptQuotesOld": "application/vnd.interoperability.quotes+json;version=1.0",
    "acceptQuotesNotSupported": "application/vnd.interoperability.quotes+json;version=2.0",
    "acceptTransfers": "application/vnd.interoperability.transfers+json;version=1.1",
    "acceptTransfersOld": "application/vnd.interoperability.transfers+json;version=1.0",
    "acceptTransfersNotSupported": "application/vnd.interoperability.transfers+json;version=2.0",
    "acceptTransactionRequests": "application/vnd.interoperability.transactionRequests+json;version=1.1",
    "acceptTransactionRequestsOld": "application/vnd.interoperability.transactionRequests+json;version=1.0",
    "acceptTransactionRequestsNotSupported": "application/vnd.interoperability.transactionRequests+json;version=2.0",
    "acceptAuthorizations": "application/vnd.interoperability.authorizations+json;version=1.1",
    "acceptAuthorizationsOld": "application/vnd.interoperability.authorizations+json;version=1.0",
    "acceptAuthorizationsNotSupported": "application/vnd.interoperability.authorizations+json;version=2.0",
    "acceptBulkTransfers": "application/vnd.interoperability.bulkTransfers+json;version=1.1",
    "acceptBulkTransfersOld": "application/vnd.interoperability.bulkTransfers+json;version=1.0",
    "acceptBulkTransfersNotSupported": "application/vnd.interoperability.bulkTransfers+json;version=2.0",
    "accountId": "6",
    "amount": "100",
    "batchToIdValue1": "27713803066",
    "batchToIdValue2": "27713803067",
    "condition": "n2cwS3w4ekGlvNYoXg2uBAqssu3FCoXjADE2mziU5jU",
    "contentType": "application/vnd.interoperability.parties+json;version=1.1",
    "contentTypeTransfers": "application/vnd.interoperability.transfers+json;version=1.1",
    "contentTypeTransfersOld": "application/vnd.interoperability.transfers+json;version=1.0",
    "contentTypeTransfersNotSupported": "application/vnd.interoperability.transfers+json;version=2.0",
    "contentTypeParties": "application/vnd.interoperability.parties+json;version=1.1",
    "contentTypePartiesOld": "application/vnd.interoperability.parties+json;version=1.0",
    "contentTypePartiesNotSupported": "application/vnd.interoperability.parties+json;version=2.0",
    "contentTypeParticipants": "application/vnd.interoperability.participants+json;version=1.1",
    "contentTypeParticipantsOld": "application/vnd.interoperability.participants+json;version=1.0",
    "contentTypeParticipantsNotSupported": "application/vnd.interoperability.participants+json;version=2.0",
    "contentTypeQuotes": "application/vnd.interoperability.quotes+json;version=1.1",
    "contentTypeQuotesOld": "application/vnd.interoperability.quotes+json;version=1.0",
    "contentTypeQuotesNotSupported": "application/vnd.interoperability.quotes+json;version=2.0",
    "contentTypeTransactionRequests": "application/vnd.interoperability.transactionRequests+json;version=1.1",
    "contentTypeTransactionRequestsOld": "application/vnd.interoperability.transactionRequests+json;version=1.0",
    "contentTypeTransactionRequestsNotSupported": "application/vnd.interoperability.transactionRequests+json;version=2.0",
    "contentTypeAuthorizations": "application/vnd.interoperability.authorizations+json;version=1.1",
    "contentTypeAuthorizationsOld": "application/vnd.interoperability.authorizations+json;version=1.0",
    "contentTypeAuthorizationsNotSupported": "application/vnd.interoperability.authorizations+json;version=2.0",
    "contentBulkTransfers": "application/vnd.interoperability.bulkTransfers+json;version=1.1",
    "contentBulkTransfersOld": "application/vnd.interoperability.bulkTransfers+json;version=1.0",
    "contentBulkTransfersNotSupported": "application/vnd.interoperability.bulkTransfers+json;version=2.0",
    "currency": "USD",
    "currency2": "TZS",
    "fromDOB": "1984-01-01",
    "fromFirstName": "Firstname-Test",
    "fromFspId": "testingtoolkitdfsp",
    "fromIdType": "MSISDN",
    "fromIdValue": "44123456789",
    "fromLastName": "Lastname-Test",
    "fspiopSignature": "{\\"signature\\":\\"iU4GBXSfY8twZMj1zXX1CTe3LDO8Zvgui53icrriBxCUF_wltQmnjgWLWI4ZUEueVeOeTbDPBZazpBWYvBYpl5WJSUoXi14nVlangcsmu2vYkQUPmHtjOW-yb2ng6_aPfwd7oHLWrWzcsjTF-S4dW7GZRPHEbY_qCOhEwmmMOnE1FWF1OLvP0dM0r4y7FlnrZNhmuVIFhk_pMbEC44rtQmMFv4pm4EVGqmIm3eyXz0GkX8q_O1kGBoyIeV_P6RRcZ0nL6YUVMhPFSLJo6CIhL2zPm54Qdl2nVzDFWn_shVyV0Cl5vpcMJxJ--O_Zcbmpv6lxqDdygTC782Ob3CNMvg\\\",\\\"protectedHeader\\\":\\\"eyJhbGciOiJSUzI1NiIsIkZTUElPUC1VUkkiOiIvdHJhbnNmZXJzIiwiRlNQSU9QLUhUVFAtTWV0aG9kIjoiUE9TVCIsIkZTUElPUC1Tb3VyY2UiOiJPTUwiLCJGU1BJT1AtRGVzdGluYXRpb24iOiJNVE5Nb2JpbGVNb25leSIsIkRhdGUiOiIifQ\\"}",
    "homeTransactionId": "123ABC",
    "hubEmail": "some.email@gmail.com",
    "hub_operator": "NOT_APPLICABLE",
    "ilpPacket": "AYIDBQAAAAAAACcQJGcucGF5ZWVmc3AubXNpc2RuLnt7cmVjZWl2ZXJtc2lzZG59fYIC1GV5SjBjbUZ1YzJGamRHbHZia2xrSWpvaVptVXhNREU0Wm1NdE1EaGxZeTAwWWpJM0xUbGpZalF0TnpjMk9URTFNR00zT1dKaklpd2ljWFZ2ZEdWSlpDSTZJbVpsTVRBeE9HWmpMVEE0WldNdE5HSXlOeTA1WTJJMExUYzNOamt4TlRCak56bGlZeUlzSW5CaGVXVmxJanA3SW5CaGNuUjVTV1JKYm1adklqcDdJbkJoY25SNVNXUlVlWEJsSWpvaVRWTkpVMFJPSWl3aWNHRnlkSGxKWkdWdWRHbG1hV1Z5SWpvaWUzdHlaV05sYVhabGNrMVRTVk5FVG4xOUlpd2labk53U1dRaU9pSndZWGxsWldaemNDSjlmU3dpY0dGNVpYSWlPbnNpY0dGeWRIbEpaRWx1Wm04aU9uc2ljR0Z5ZEhsSlpGUjVjR1VpT2lKTlUwbFRSRTRpTENKd1lYSjBlVWxrWlc1MGFXWnBaWElpT2lJeU56Y3hNemd3TXprd05TSXNJbVp6Y0Vsa0lqb2ljR0Y1WlhKbWMzQWlmU3dpY0dWeWMyOXVZV3hKYm1adklqcDdJbU52YlhCc1pYaE9ZVzFsSWpwN0ltWnBjbk4wVG1GdFpTSTZJazFoZEhNaUxDSnNZWE4wVG1GdFpTSTZJa2hoWjIxaGJpSjlMQ0prWVhSbFQyWkNhWEowYUNJNklqRTVPRE10TVRBdE1qVWlmWDBzSW1GdGIzVnVkQ0k2ZXlKaGJXOTFiblFpT2lJeE1EQWlMQ0pqZFhKeVpXNWplU0k2SWxWVFJDSjlMQ0owY21GdWMyRmpkR2x2YmxSNWNHVWlPbnNpYzJObGJtRnlhVzhpT2lKVVVrRk9VMFpGVWlJc0ltbHVhWFJwWVhSdmNpSTZJbEJCV1VWU0lpd2lhVzVwZEdsaGRHOXlWSGx3WlNJNklrTlBUbE5WVFVWU0luMTkA",
    "invalidFulfillment": "_3cco-YN5OGpRKVWV3n6x6uNpBTH9tYUdOYmHA-----",
    "invalidToIdType": "ACCOUNT_ID",
    "invalidToIdValue": "27713803099",
    "note": "test",
    "payeeIdType": "MSISDN",
    "payeeIdentifier": "17039811902",
    "payeefsp": "$param_simNamePayeefsp",
    "payeefspEmail": "some.email@gmail.com",
    "payerIdType": "MSISDN",
    "payerIdentifier": "17039811901",
    "payerfsp": "testingtoolkitdfsp",
    "payerfspEmail": "some.email@gmail.com",
    "receiverMSISDN": "27713803912",
    "testfsp1Email": "some.email@gmail.com",
    "testfsp1IdType": "MSISDN",
    "testfsp1Identifier": "17039811903",
    "testfsp1MSISDN": "17039811903",
    "testfsp2Email": "some.email@gmail.com",
    "testfsp2IdType": "MSISDN",
    "testfsp2Identifier": "17039811904",
    "testfsp2MSISDN": "17039811904",
    "toFspId": "$param_simNamePayeefsp",
    "toIdType": "MSISDN",
    "toIdValue": "27713803912",
    "toIdValueDelete": "27713803913",
    "toAccentIdType": "MSISDN",
    "toAccentIdValue": "97039819999",
    "toAccentIdDOB": "2000-01-01",
    "toAccentIdFirstName": "Seán",
    "toAccentIdMiddleName": "François",
    "toAccentIdLastName": "Nuñez",
    "toAccentIdFspId": "$param_simNamePayeefsp",
    "toBurmeseIdType": "MSISDN",
    "toBurmeseIdValue": "2224448888",
    "toBurmeseIdDOB": "1990-01-01",
    "toBurmeseIdFirstName": "ကောင်းထက်စံ",
    "toBurmeseIdMiddleName": "အောင်",
    "toBurmeseIdLastName": "ဒေါ်သန္တာထွန်",
    "toBurmeseIdFspId": "$param_simNamePayeefsp",
    "validCondition": "GRzLaTP7DJ9t4P-a_BA0WA9wzzlsugf00-Tn6kESAfM",
    "validCondition2": "kPLCKM62VY2jbekuw3apCTBg5zk_mVs9DD8-XpljQms",
    "validFulfillment": "UNlJ98hZTY_dsw0cAqw4i_UN3v4utt7CZFB4yfLbVFA",
    "validIlpPacket2": "AYIC9AAAAAAAABdwHWcucGF5ZWVmc3AubXNpc2RuLjIyNTU2OTk5MTI1ggLKZXlKMGNtRnVjMkZqZEdsdmJrbGtJam9pWmpRMFltUmtOV010WXpreE1DMDBZVGt3TFRoa05qa3RaR0ppWVRaaVl6aGxZVFpqSWl3aWNYVnZkR1ZKWkNJNklqVTBaRFZtTURsaUxXRTBOMlF0TkRCa05pMWhZVEEzTFdFNVkyWXpZbUl5TkRsaFpDSXNJbkJoZVdWbElqcDdJbkJoY25SNVNXUkpibVp2SWpwN0luQmhjblI1U1dSVWVYQmxJam9pVFZOSlUwUk9JaXdpY0dGeWRIbEpaR1Z1ZEdsbWFXVnlJam9pTWpJMU5UWTVPVGt4TWpVaUxDSm1jM0JKWkNJNkluQmhlV1ZsWm5Od0luMTlMQ0p3WVhsbGNpSTZleUp3WVhKMGVVbGtTVzVtYnlJNmV5SndZWEowZVVsa1ZIbHdaU0k2SWsxVFNWTkVUaUlzSW5CaGNuUjVTV1JsYm5ScFptbGxjaUk2SWpJeU5UQTNNREE0TVRneElpd2labk53U1dRaU9pSndZWGxsY21aemNDSjlMQ0p3WlhKemIyNWhiRWx1Wm04aU9uc2lZMjl0Y0d4bGVFNWhiV1VpT25zaVptbHljM1JPWVcxbElqb2lUV0YwY3lJc0lteGhjM1JPWVcxbElqb2lTR0ZuYldGdUluMHNJbVJoZEdWUFprSnBjblJvSWpvaU1UazRNeTB4TUMweU5TSjlmU3dpWVcxdmRXNTBJanA3SW1GdGIzVnVkQ0k2SWpZd0lpd2lZM1Z5Y21WdVkza2lPaUpWVTBRaWZTd2lkSEpoYm5OaFkzUnBiMjVVZVhCbElqcDdJbk5qWlc1aGNtbHZJam9pVkZKQlRsTkdSVklpTENKcGJtbDBhV0YwYjNJaU9pSlFRVmxGVWlJc0ltbHVhWFJwWVhSdmNsUjVjR1VpT2lKRFQwNVRWVTFGVWlKOWZRAA",
    "NORESPONSE_SIMPAYEE_NAME": "$param_simNameNoResponsePayeefsp",
    "SIM1_NAME": "$param_simNameTestfsp1",
    "SIM2_NAME": "$param_simNameTestfsp2",
    "SIM3_NAME": "$param_simNameTestfsp3",
    "SIM4_NAME": "$param_simNameTestfsp4",
    "SIM1_MSISDN": "17039811903",
    "SIM2_MSISDN": "17039811904",
    "SIM3_MSISDN": "17891239873",
    "SIM4_MSISDN": "17891239872",
    "SIM1_JWS_KEY": "-----BEGIN PRIVATE KEY-----\n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\nDgoQeSng2kt5Z6mkoDIQTs7nEflb4w==\n-----END PRIVATE KEY-----\n",
    "SIM2_JWS_KEY": "-----BEGIN PRIVATE KEY-----\n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\nTv4G862WYeqD1fdyZaKQ3b9fAQEq1g==\n-----END PRIVATE KEY-----\n",
    "SIMPAYEE_JWS_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDMu126miewCUCT\n7f49B0SyCPFGzmqGSs9rTPbk1se+BBhqfhsfkZj6cRRfrlg3rme6we0Ib2AF5TQL\nnoSBlDAimQcNOHXrqpAY/B0l/mgyUwmfv0NJ3UjZuCFuw3HRrU/oSUfXoDITC+Bi\n120w4FY2B/vPn+1iC/tsaCayneoaV/Sedq7H9+smEnQfGl3p5QJp/B2Ws3Bz1HqI\nIoxLEaO9VMeDHQPvNJn/7g9erqA5vIhmgLS46worOVjdRLH2SECH73qp8Wg0rJ8Y\neW2kQ8kuY4uHcG3MO6drYrC011U0ZyM90KV7dv2Y0h2FHlpn9s/pmb630m5ELpnB\nT/pYTLcXAgMBAAECggEADqk6Qz3SgBeMMYEWYZ4ZdsW6Ktpm+Xqg/kDy4JywOB9z\nSikBXeeKH3Z6ltwq2BicDV020Wb8Zt+s3vTOmLhDzC544/hPmtKfjWfR2eHX6gaq\nm+8ml+20pQFmb4Kn2MlC/Xzwm/SOXBvPyUmTua95rQExsK12DT0+F4YhLfhYsTh2\nHfkEzdFW4rrd+9ddKG1ZANS4ZaiMyzhtvUWeEBypBtVf+kBk+51t9pLCdjuynb8I\nWylSDhikT3/YQ/3g/Sz3SMp1u4x0GQe9FWYrnPzzp5LnM5fm49v8JWVHUvd0TOi0\ndQV+LYlgSD38YPpi4iKQSh0Zf0EBfbA83GsX2ArJ7QKBgQDmvcA6PqPo0OV/7RKY\nJuziA3TpucL8iVM1i7/Lv6+VkX88uDvEjwLoNAiYcgIm/CMK7WAwA+Dzn4r38EHB\nBKF4KRhP0qQS0KLXsd0tdsmAB0In7+cbKL4ttqNUP98xZAkTLJq9PXqTKN0qtyw4\nSfIsVMjDGoeSdWHObZYbGKICfQKBgQDjJLwolDrVX29V4zVmxQYH5iN+5kwKXHXj\nsuHBrW02Oj/GQFh3Xj6JQi3mzTWYhHwhA4pdaQtNYqTaz9Ic/O1VNPic2ovtg+cd\n7sh86qdQ4QZYhN3RT4oX///u6+UK90llh9hEBo3GuZ4X47tuByNtD4SFAlULrkSm\nfW4XaC3gIwKBgGil6HfCDx65F00UnVlKVicPQEf8ivVz5rwjPIJQ1nZ0PYuxVtIH\ntl7PspJJKra5pb7/957vM2fqlOFsIrZCvmS75p3VP7qUyzYeIdzLwgmBwTxRrrP/\nn3kmGx9LtJM29nKuySNIrb3uS5hi6PhCeUYn0cHC13fSKuCvjOOPIXMVAoGBAJg+\nCPdR0tUs8Byq+yH0sIQe1m+5wAG50zJYtUPxD6AnDpO8kQ8A1f19o/JsXJ3rPp+K\nFfVh8LdfhIs8e+H+DLztkizftqXtoLzJTQuc46QsDurJszsVisNnTI1BAvWEpWct\n0+BUXDZ0NuhgNUIb+rygh/v2gjYgCddlfqKlqwntAoGBAM5Kpp5R0G0ioAuqGqfZ\nsHEdLqJMSepgc6c7RC+3G/svtS2IqCfyNfVMM3qV5MY3J7KnAVjGOw2oJbXcPLXa\nuutsVVmPx2d/x2LZdc8dYYcdOQZvrUhmALhAPXM4SRujakxh+Uxi1VOiW+fZL8aW\nuu1pxuWD0gTJxFkp6u4YIAhw\n-----END PRIVATE KEY-----\n",
    "SIMPAYER_JWS_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCg9eU66hg4ZAE6\njM4U8ylXQwUz9cdmzS3JyW+1bbgv77peMKSU/wFsi4QRwmbrYze9baFnGCKnS75E\nvCchib5vJxp3MDWzi/TGxmzgWdJRzkyCiI5C6dCgVL71MjsFgN3TN63wEf5sEU2I\neoJ8yXJM0pUG9f9NO7p/IGliDmt6C7EA7D9kQWigufmX0ZTVNKI07fKwC/AEKLp7\nkx99pvsCq8m184EEL15Q/NhA7R/5zKoHvmJa6Jd7tM0i0xn8IKOkNVFu3YIafAEC\nQWQwRbanFEeRc3tH3bEoYM8c74r+W+YxCG7nUf16XCk132XVffbHVl+wFgo18YB/\nsAJmcbePAgMBAAECggEAGQGKnsf+gkg7DqMQYx3Rxt5BISzmURjAK9CxG6ETk9Lt\nA7QP5ZvmVzwnhPDMN3Z/Et1EzXTo8U+pnBkVBTdWkAMlr+2b8ixklzr9cC9UJuRj\na4YWf9u+TyJLVmF63OSD0cwdKCZLffOENZc+zW8oZDn08BNomdGVLCnXZWXzGY8X\nKaJTJr29jEgkKOqFXdAHrsmj7TBtqSLZKx2IHdCmi05+5JCxVLPgnDiCicZ9zEii\nyWw57Q1migFIcw6ZQP4RyjgH1o70B+zo3OL7IQEirE17GUgK16XD8xi8hWCYTj5n\nxOz9yfVfPuYom/9Xbm5kYJZKE2HOZ3Lg8pUnWncuNQKBgQDbaOoACQPhVxQK1qYR\nRbW0I5Rn0EDxzsFPEpu3eXHoIYGXi8u/ew9AzFmGu+tKYJV5V4BCXo5x2ddE+B8B\ndXhyHLGfeV8tWKYKBpatolVxxKDL/9fnxoGIAO9cc91ieOm5JxmKscCVP1UnOXHZ\nuomSfAbGQwYDtMd2bJKkE1z0qwKBgQC7zacuv1PMaDFksHuNNRG+aZ74pJ77msht\nvJoKyaQcktD0xmIXhFfJvK4cclzG7s5jxCsu2ejimgmfVzgXlLEMrJFvSdFkD2SS\ngGqoxq5c9g8ssvt7xwr7aJ+VYYWTWRzJrOUny+99UbwHedu0EHL1BYILwy67Lium\nsgUeeCEgrQKBgGv+7f7qcRB/jgvvr3oc990dDjUzGmRrQlcrb54Vlu2NYH45fyZW\n6iEY9JAO+zd25tv9J9KDPFXpxb3a61gKfCie2wcF9MUbN08EAzKgDrKa+BKxcZJR\n8PwCic7V8QhBP7m09yt/Zq2PqNhPvCxRVtnVVnhMES/N0cgGlP9R0JVVAoGAHU2/\nkmnEN5bibiWjgasQM7fjWETHkdbbA1R0bM59zv+Rnz/9OlIqKI5KVKH7nAbTKXoI\niuzxi7ohWj2PwQ4wehvLLaRFCenk9X8YJXGq71Jtl7ntx6iNLCFtFS/8WbuD5GwX\n7ZfCrLk+L6RyBayzY0wSuKch+Y8AvKf2aISyFpkCgYEAjSfEjz9Cn+27HdiMoBwa\n+fyyoosci/6OBxj/WTKvV6KUYLBfFoAYpb9rqrbvnfyyc0UiAYQeMJAOWQ1kkzY4\nzXs63iPQi2UeGPJZ7RsT+31DSaG9YiQdrInsUrlm8hi1C7Pg/NNt6Y1G0WhWYrvF\niNK0yCENMhSoOTtbT9tmGi0=\n-----END PRIVATE KEY-----\n",
    "TESTFSP1_JWS_PUB_KEY": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2R3IuEDpqDtsS96emI0v\ndCJpeb/lnCxR2Nw5x6Z3GjC9PRFCJ2gsS2Zq70NaUQ5yWrrrZ9DZ8PjgCXqftUKG\n42uFsibLFpN09IjQuZCDuAkCdEjMgm+xies47ajRzl6evOc0ClkQBZVGybl9RAr6\nNRTFOYkYjJ0xS0MNkfRkDiOEu5BA/XKb5oLbyVMjGyvLgyS1g41x4fA+Ccb5PENa\nh9dqkFJ3j218Rs+bGytrVqrrCCjV1FiI+Y9YjKuTRRo7U/jcGHLfEc7YRcP2U9os\nxQxFvhHxR7W0e74fAU8B8YIJzwjaQvrEh9SJRc2IZsh6EdBAXXmbk4sHKyhoX0by\nUQIDAQAB\n-----END PUBLIC KEY-----\n",
    "TESTFSP2_JWS_PUB_KEY": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv7k0Mqy0jSXFpHD9/a+Y\nl5djXq6HdyC+BsSA/sRKczEBKQyW8mEJVILAKkOibWzK7e+SJjQPbFjgqiUZvRI5\n+ggHkSJXEV28Bi2sF58A15sQjwaSkE2vBwLAL5GftSmao0QSozSfQ+RFw2N+loRG\nYedXZpRMsYFr1uA1qavcBjoj7JqPpID7UaTgXwwHWbV+j2uhQfotqRvOQ5KTmx5H\nJa+VjPu+xAC7mmcL+dxmeBpbJJD5Li8B8ggJXGJUk+En6XSIgZkQ6vKvC9HyasE6\nWZLXU+JJoCp2wkCPNTRxzPE2PGnlI0a4ZP2/y/2yacc4HQGBhEMc+SVT/VSZaMS+\nAQIDAQAB\n-----END PUBLIC KEY-----",
    "payerfspSettlementAccountId": "",
    "payerfspSettlementAccountBalanceBeforeFundsIn": "",
    "payerfspSettlementAccountBalanceAfterFundsIn": "",
    "fundsInPrepareTransferId": "",
    "fundsInPrepareAmount": "",
    "SIMPLE_ROUTING_MODE_ENABLED": true,
    "mobileSimPayerFsp": "pinkbankfsp",
    "mobileSimPayeeFsp": "greenbankfsp",
    "ON_US_TRANSFERS_ENABLED": false,
    "expectedPartiesVersion": "1.1",
    "expectedParticipantsVersion": "1.1",
    "expectedQuotesVersion": "1.1",
    "expectedTransfersVersion": "1.1",
    "expectedAuthorizationsVersion": "1.1",
    "expectedTransactionRequestsVersion": "1.1",
    "toSubIdValue": "30",
    "fromSubIdValue": "30",
    "cgscurrency": "INR",
    "settlementtestfsp2bankMSISDN": "27713813915",
    "settlementtestfsp1bankMSISDN": "27713813914",
    "settlementtestfsp4bankMSISDN": "27713813917",
    "settlementtestfsp3bankMSISDN": "27713813916",
    "DELAY_CGS": 5000,
    "settlementpayeefspNoExtensionMSISDN": "27714923918",
    "NORESPONSE_NAME": "$param_simNameNoResponsePayeefsp",
    "payeefspMSISDN": "17039811907",
    "payerfspMSISDN": "17891239876",
    "settlementtestNonExistingMSISDN": "22244803917",
    "NET_DEBIT_CAP": "50000",
    "HOST_ORACLE_CONSENT": "http://consent-oracle:3000",
    "DFSPA_NAME": "dfspa",
    "DFSPA_CB_FSPIOP": "http://$release_name-sim-tp-dfspa-scheme-adapter:4000",
    "DFSPA_CB_THIRDPARTY": "http://$release_name-sim-tp-dfspa-thirdparty-sdk:4005",
    "DFSPB_NAME": "dfspb",
    "DFSPB_CB_FSPIOP": "http://$release_name-sim-tp-dfspb-scheme-adapter:4000",
    "DFSPB_CB_THIRDPARTY": "http://$release_name-sim-tp-dfspb-thirdparty-sdk:4005",
    "PISP_NAME": "pisp",
    "PISP_CB_FSPIOP": "http://$release_name-sim-tp-pisp-scheme-adapter:4000",
    "PISP_CB_THIRDPARTY": "http://$release_name-sim-tp-pisp-thirdparty-sdk:4005",
    "CENTRALAUTH_NAME": "centralauth",
    "CENTRALAUTH_CB_FSPIOP": "http://auth-svc:4004",
    "PISP_THIRDPARTY_SDK_OUTBOUND_URL": "http://$release_name-sim-tp-pisp-thirdparty-sdk:4006",
    "PISP_BACKEND_TESTAPI_URL": "http://$release_name-sim-tp-pisp-backend:3003",
    "PISP_CALLBACK_URL": "http://$release_name-sim-tp-pisp-scheme-adapter:4000",
    "PISP_SDK_TESTAPI_URL": "http://$release_name-sim-tp-pisp-scheme-adapter:4002",
    "PISP_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-tp-pisp-scheme-adapter:4002",
    "DFSPA_BACKEND_TESTAPI_URL": "http://$release_name-sim-tp-dfspa-backend:3003",
    "DFSPA_CALLBACK_URL": "http://$release_name-sim-tp-dfspa-scheme-adapter:4000",
    "DFSPA_SDK_TESTAPI_URL": "http://$release_name-sim-tp-dfspa-scheme-adapter:4002",
    "DFSPA_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-tp-dfspa-scheme-adapter:4002",
    "DFSPB_BACKEND_TESTAPI_URL": "http://$release_name-sim-tp-dfspb-backend:3003",
    "DFSPB_CALLBACK_URL": "http://$release_name-sim-tp-dfspb-scheme-adapter:4000",
    "DFSPB_SDK_TESTAPI_URL": "http://$release_name-sim-tp-dfspb-scheme-adapter:4002",
    "DFSPB_SDK_TESTAPI_WS_URL": "ws://$release_name-sim-tp-dfspb-scheme-adapter:4002"
  }
}

"""

def fix_values_files_json(p,ceplist):
    # ceplist = chart exclue path list 
    # any chart in the ceplist does not need to have the json formatting fixed
    # note that in testing the json works ok , it is just that it is even harder to 
    # read after being re-written by ruamel for the v14.x api updates 
    print("-- fix formatting of the json in the values files   -- ") 
    json_cnt = 0
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*values.yaml'):
        #print(f" parent is {vf.parent/vf} and granny is {vf.parent.parent/vf} ")
        if vf.parent.parent in ceplist or vf.parent in ceplist : 
            print(f"DEBUG5 excluding values files updating for {vf.parent.parent/vf}")
        else : 
            line_cnt = 0 
            outfile = open("/tmp/out.txt","w")
            with open(str(vf)) as f:
                lines = f.readlines()

            with open(str(vf), "w") as f:
            #with open("/tmp/out.txt", "w") as f:
                for l in lines : 
                    line_cnt += 1 
                    #l = l.rstrip()
                    if re.search(r".json:",l): 
                        jstart=re.search(r".json:",l).start()
                        if re.search(r"#",l[0:jstart]):
                            # then the .json is commented out 
                            f.writelines(l)
                        else:
                            print(f"===> Processing file < {vf.parent}/{vf.name} > ") 
                            json_cnt += 1 
                            # #print(f"jstart is {jstart} and contents of line at jstart is {l[jstart:50]}")
                            # #jstartpos=re.search(r"{\"",l[jstart:]).start()
                            # jstartpos=re.search(r"{\"",l[jstart:]).start()
                            # l=l.substr(r"{\",l)
                            # print(f"jstartpos is {jstartpos} at line number {line_cnt} json looks like  {l[jstartpos:50]}")
                            x = l.find("{\"",jstart)
                            # hard code a couple of exceptions 
                            if l.find("config:") > -1 and l.find("null}}") > -1: 
                                print("fixing the null}}")
                                # config: and the .json are on one line so remove the trailing brace 
                                l=re.sub(r"null}}","null}",l)
                            #print(f" start {x}, line num is {line_cnt} and substr is {l[x:50]}")
                            #print ()
                            elif l.find("ttkInputValues") > -1 :
                                print("fixing the ttkInoutValues")
                                l = "           hub-k8s-default-environment.json: &ttkInputValues {" + s1
                                f.writelines(l)
                            else : 
                                # get the start of the line 
                                lstart=l[0:x-1] + " "
                                print(f"ok trying to load json: inserting lstartr [{lstart}]")
                                try : 
                                    data = json.loads(l[x:])
                                    l=lstart + json.dumps(data, indent=4)
                                    f.writelines(l)
                                    #print(json.dumps(data, indent=4))
                                    #print(l)
                                except Exception as e : 
                                    #f.writelines(f"DEBUG1 [{line_cnt}]" + l)
                                    print(f"Error with json : in file {vf.parent}/{vf.name}  start {x}, line num is {line_cnt} and substr is {l[x:45]}")
                                    print(l)
                                    #outfile.writelines(l)
                    else: 
                        f.writelines(l)

    print(f" total number of .json sections  [{json_cnt}]")

def fix_ingress_values_indents(p,ceplist):
    delete_list = [
           "# Secrets must be manually created in the namespace",
          "# - secretName: chart-example-tls",
          "#   hosts:",
          "#     - chart-example.local"
    ]
    line_cnt = 0 
    ing_section_cnt = 0 
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*values.yaml'):
        if vf.parent.parent in ceplist or vf.parent in ceplist : 
            #print(f"DEBUG6 Excluding values files updating for {vf.parent.parent/vf}")
            continue ; 
        else : 
            #outfile = open("/tmp/out.txt","w")
            with open(str(vf)) as f:
                lines = f.readlines()

            with open(str(vf), "w") as f:
                ing_section=False
                for l in lines : 
                    line_cnt += 1 
                    if re.search(r"ingress:",l):
                        ing_section=True
                        ing_section_cnt += 1 
                        # how many spaces before the ingress
                        indent1=re.search(r"ingress:",l).start()
                        #print(f"ingress found at line {line_cnt} and col {indent1} ing_section is {ing_section}")
                    elif re.search(r"className: \"nginx\"",l):
                        ing_section=False

                    if ing_section: 
                        #fix the indentation 
                        x = l.find(r"##")
                        #print (f"hello ing_section is {ing_section} and x is {x}")
                        if x > -1 : 
                            #new_spaces = indent1+2
                            spaces_str="                  "
                            l1 = re.sub(r"^.*##",spaces_str[0:indent1+2]+"##",l) 
                            #print(f"comment found at col {x} but ingress is at col {indent1} ")
                            f.writelines(l1)
                        else:
                            f.writelines(l)
                    else: 
                        found=False
                        for item in delete_list: 
                            if l.find(item) > -1:
                                found=True 
                        if not found : 
                            f.writelines(l)
    print(f" total number of ingress sections  [{ing_section_cnt}]")         

def parse_args(args=sys.argv[1:]):
    parser = argparse.ArgumentParser(description='Automate modifications across mojaloop helm charts')
    parser.add_argument("-d", "--directory", required=True, help="directory for helm charts")
    parser.add_argument("-v", "--verbose", required=False, action="store_true", help="print more verbose messages ")
    parser.add_argument("-k", "--kubernetes", type=str, default="microk8s", choices=["microk8s", "k3s" ] , help=" kubernetes distro  ")

    args = parser.parse_args(args)
    if len(sys.argv[1:])==0:
        parser.print_help()
        parser.exit()
    return args

##################################################
# main
##################################################
def main(argv) :
    args=parse_args()

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    # yaml = YAML()
    # yaml.allow_duplicate_keys = True
    # yaml.preserve_quotes = True
    # yaml.indent(mapping=2, sequence=6, offset=2)
    # yaml.width = 4096

    chart_names_exclude_list = [
        "finance-portal-settlement-management",
        "finance-portal",
        "thirdparty",
        "thirdparty/chart-tp-api-svc",
        "thirdparty/chart-consent-oracle",
        "thirdparty/chart-auth-svc",
        "mojaloop-simulator",
        "keycloak",
        "monitoring",
        "monitoring/promfana",
        "monitoring/elk",
        "ml-testing-toolkit",
        "ml-testing-toolkit/chart-keycloak",
        "ml-testing-toolkit/chart-backend",
        "ml-testing-toolkit/chart-frontend",
        "ml-testing-toolkit/chart-connection-manager-backend",
        "ml-testing-toolkit/chart-connection-manager-frontend"
    ]

    chart_path_exclude_list = []
    for c in chart_names_exclude_list : 
        chart_path_exclude_list.append(p / c)


    # s2=re.sub(r"\\\\\\\\",r"\\\\\\",s1)
    # print(s2)
    # data = json.loads(s1)

    # print(json.dumps(data, indent=4))
    
    # l = """
    # production.json: {"PORT": 4004, "HOST": "0.0.0.0"
    # """
    # s = l 
    # jstart=re.search(r".json:",l).start()
    # print(f"jstart is : {jstart} and substr is {l[jstart:]}")
    # x = s.find("{\"")
    # print(f"x is {x}")
    # sys.exit(1)
    # # print(f"s1[5:] is {s1[5:]}")

    fix_values_files_json(p,chart_path_exclude_list)
    fix_ingress_values_indents(p,chart_path_exclude_list)
 
if __name__ == "__main__":
    main(sys.argv[1:])