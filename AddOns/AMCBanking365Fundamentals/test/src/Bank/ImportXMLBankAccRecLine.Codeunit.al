codeunit 132550 "Import XML Bank Acc. Rec. Line"
{
    Permissions = TableData "Bank Export/Import Setup" = rimd;
    Subtype = Test;
    TestPermissions = NonRestrictive;

    trigger OnRun()
    begin
        // [FEATURE] [Bank Reconciliation]
    end;

    var
        LibraryERMCountryData: Codeunit "Library - ERM Country Data";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryERM: Codeunit "Library - ERM";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryRandom: Codeunit "Library - Random";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit Assert;
        IBANTxt: Text[50];
        CurrTxt: Text[10];
        IsInitialized: Boolean;
        AssertMsg: Label '%1 Field:"%2" different from expected.';
        MultiStatementErr: Label 'The file that you are trying to import contains more than one bank statement.';
        MissingStatementDateInDataMsg: Label 'The statement date was not found in the data to be imported.';
        NamespaceTxt: Label 'urn:iso:std:iso:20022:tech:xsd:camt.053.001.02';
        BankAccMismatchQst: Label 'Bank account %1 does not have the bank account number';
        MissingBankAccNoInDataErr: Label 'The bank account number was not found in the data to be imported.';
        MissingBankAccNoQst: Label 'Bank account %1 does not have a bank account number. Do you want to continue?';
        BankAccCurrErr: Label 'The bank statement that you are importing contains transactions in currencies other than the Currency Code ';
        CurrCodeErr: Label '%1 of bank account %2.';
        MissingBalTypeInDataMsg: Label 'The balance type was not found in the data to be imported.';
        MissingClosingBalanceInDataMsg: Label 'The closing balance was not found in the data to be imported.';

    [Test]
    [HandlerFunctions('WrongBankAccNoConfirmHandler')]
    [Scope('OnPrem')]
    procedure VerifyBankAccIBAN()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFile(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        BankAcc.IBAN := LibraryUtility.GenerateGUID();
        BankAcc.Modify();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        // Exercise
        LibraryLowerPermissions.SetBanking();
        LibraryVariableStorage.Enqueue(BankAcc."No.");
        BankAccReconciliation.ImportBankStatement();

        // Verify: In confirm handler.
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyIBANMissingFromData()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFileNoIBAN(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        BankAcc.IBAN := LibraryUtility.GenerateGUID();
        BankAcc.Modify();
        LibraryLowerPermissions.SetBanking();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        // Exercise
        asserterror BankAccReconciliation.ImportBankStatement();

        // Verify
        Assert.ExpectedError(MissingBankAccNoInDataErr);
    end;

    [Test]
    [HandlerFunctions('MissingStmtDateMsgHandler')]
    [Scope('OnPrem')]
    procedure VerifyStatementDateMissingFromData()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFileNoStatementDate(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify: In message handler.
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure VerifyBalTypeMissingFromData()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFileNoBalType(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify done by messagehandlers
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure VerifyClosingBalMissingFromData()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFileNoClosingBal(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify done by messagehandlers
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure VerifyCrdDbtIndMissingFromData()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFileNoCrdDbtInd(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify done by messagehandlers
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyBankAccCurrency()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFile(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        LibraryLowerPermissions.SetBanking();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);
        LibraryLowerPermissions.SetO365Full();
        BankAcc.IBAN := IBANTxt;
        BankAcc."Currency Code" :=
          LibraryERM.CreateCurrencyWithExchangeRate(DMY2Date(1, 1, 2000), 1, 1);
        BankAcc.Modify();

        // Exercise
        asserterror BankAccReconciliation.ImportBankStatement();

        // Verify
        Assert.ExpectedError(BankAccCurrErr);
        Assert.ExpectedError(StrSubstNo(CurrCodeErr, BankAcc."Currency Code", BankAcc."No."));
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyMultiStatement()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteMultiStatementCAMTFile(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        LibraryLowerPermissions.SetBanking();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);
        LibraryLowerPermissions.SetO365Full();
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();

        // Exercise
        asserterror BankAccReconciliation.ImportBankStatement();

        Assert.ExpectedError(MultiStatementErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyImportedLines()
    var
        DataExch: Record "Data Exch.";
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        TempExpdBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line" temporary;
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
        EntryNo: Integer;
        LineNo: Integer;
    begin
        Initialize();

        // Pre-Setup
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFile(OutStream, 'UTF-8');

        // Setup
        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify Bank Acc. Rec. Lines
        DataExch.SetRange("Data Exch. Def Code", 'SEPA CAMT');
        DataExch.FindLast();
        EntryNo := DataExch."Entry No.";
        LineNo := BankAccReconciliationLineTemplate."Statement Line No.";

        CreateLine(TempExpdBankAccReconciliationLine, BankAccReconciliationLineTemplate, EntryNo, 1, LineNo * 1,
          DMY2Date(1, 1, Date2DMY(WorkDate(), 3)), DMY2Date(3, 3, Date2DMY(WorkDate(), 3)), '', 'Cronus Ltd.', '', 105678.5, '');
        CreateLine(TempExpdBankAccReconciliationLine, BankAccReconciliationLineTemplate, EntryNo, 2, LineNo * 2,
          DMY2Date(3, 3, Date2DMY(WorkDate(), 3)), DMY2Date(5, 5, Date2DMY(WorkDate(), 3)), '', 'Payer 1234', '', 105.42, '');

        AssertDataInTable(TempExpdBankAccReconciliationLine, BankAccReconciliationLineTemplate, '');

        // Verify Bank Acc. Rec.
        VerifyBankAccRec(BankAccReconciliation, DMY2Date(6, 6, Date2DMY(WorkDate(), 3)), 435678.5);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyImportedLinesForBankDataConvServ()
    var
        DataExch: Record "Data Exch.";
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        TempExpdBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line" temporary;
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
        EntryNo: Integer;
        LineNo: Integer;
    begin
        Initialize();

        // Setup.
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, IBANTxt, Format(DMY2Date(2, 2, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify Bank Acc. Rec. Lines
        DataExch.SetRange("Data Exch. Def Code", 'BANKDATACONVSERVSTMT');
        DataExch.FindLast();
        EntryNo := DataExch."Entry No.";
        LineNo := BankAccReconciliationLineTemplate."Statement Line No.";

        CreateLine(TempExpdBankAccReconciliationLine, BankAccReconciliationLineTemplate, EntryNo, 1, LineNo,
          DMY2Date(1, 1, 2016), 0D, 'UstrdText', 'Name', 'UstrdText', 150.75, 'Address GB');
        AssertDataInTable(TempExpdBankAccReconciliationLine, BankAccReconciliationLineTemplate, '');
        VerifyBankAccRec(BankAccReconciliation, DMY2Date(2, 2, 2016), 150.75);
    end;

    [Test]
    [HandlerFunctions('ConfirmHandlerYes')]
    [Scope('OnPrem')]
    procedure ImportLinesForBankDataConvServMissingStmtNo()
    var
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        BankAccReconciliation: TestPage "Bank Acc. Reconciliation";
        OutStream: OutStream;
    begin
        // [FEATURE] [UI]
        Initialize();

        // Setup.
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc."Last Statement No." := '';
        BankAcc.Modify();

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, IBANTxt, Format(DMY2Date(2, 2, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.OpenNew();
        BankAccReconciliation.BankAccountNo.SetValue(BankAcc."No.");
        BankAccReconciliation.ImportBankStatement.Invoke();

        // Verify.
        BankAccReconciliation.StatementNo.AssertEquals('1');
        Assert.IsTrue(BankAccReconciliation.StmtLine.First(), 'Record was not imported.');
        BankAccReconciliation.StatementEndingBalance.AssertEquals(Format(150.75));
    end;

    [Test]
    [HandlerFunctions('WrongBankAccNoConfirmHandler')]
    [Scope('OnPrem')]
    procedure VerifyIBANForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 1.1] Import a bank statement file, that should be checked against the bank acc. no. of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given IBAN.
        // [GIVEN] A bank statement file for a bank account with a different IBAN.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is a confirmation dialog informing the user that account numbers mismatch.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc.IBAN := LibraryUtility.GenerateGUID();
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, IBANTxt, Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        LibraryVariableStorage.Enqueue(BankAcc."No.");
        BankAccReconciliation.ImportBankStatement();

        // Verify: in confirm handler.
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyAlteredIBANForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
        BankAccNo: Text[10];
    begin
        // [SCENARIO 1.2] Import a bank statement file, that should be checked against the bank acc. no. of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given IBAN.
        // [GIVEN] A bank statement file for a bank account with an IBAN that is slightly different (spaces and dashes).
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] Import is successful.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAccNo := LibraryUtility.GenerateGUID();
        BankAcc.IBAN := PadStr('', 3, '-') + ' ' + BankAccNo + ' ' + PadStr('', 3, '-');
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, ' ' + BankAccNo + ' ', Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify: no confirm dialog.
    end;

    [Test]
    [HandlerFunctions('WrongBankAccNoConfirmHandler')]
    [Scope('OnPrem')]
    procedure VerifyBankAccNoForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 2] Import a bank statement file, that should be checked against the bank acc. no. of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no..
        // [GIVEN] A bank statement file for a bank account with a different bank account no.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is a confirmation dialog informing the user that account numbers mismatch.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc."Bank Branch No." := Format(LibraryRandom.RandIntInRange(1111, 9999));
        BankAcc."Bank Account No." := LibraryUtility.GenerateGUID();
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, IBANTxt, Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        LibraryVariableStorage.Enqueue(BankAcc."No.");
        BankAccReconciliation.ImportBankStatement();

        // Verify: confirm handler.
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyMissingBankAccNoFromDataForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 3] Import a bank statement file, that should be checked against the bank acc. no. of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no..
        // [GIVEN] A bank statement file for a bank account with an empty bank account no.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is an error informing the user that the file is missing a bank account no.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();

        LibraryLowerPermissions.SetBanking();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);
        LibraryLowerPermissions.SetOutsideO365Scope();

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, '', Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        asserterror BankAccReconciliation.ImportBankStatement();

        // Verify
        Assert.ExpectedError(MissingBankAccNoInDataErr);
    end;

    [Test]
    [HandlerFunctions('MissingBankAccNoConfirmHandler')]
    [Scope('OnPrem')]
    procedure VerifyMissingBankAccNoForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 4] Import a bank statement file, that should be checked against the bank acc. no. of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format,without a bank account no..
        // [GIVEN] A bank statement file for a bank account with an empty bank account no.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is a confirmation asking whether to continue the import.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc.IBAN := '';
        BankAcc.Modify();
        LibraryLowerPermissions.SetBanking();
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, '', Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryVariableStorage.Enqueue(BankAcc."No.");
        asserterror BankAccReconciliation.ImportBankStatement();

        // Verify: In confirm handler.
    end;

    [Normal]
    local procedure ImportFileForBankDataConvServWithCurrency(FileCurrencyCode: Text; BankAccCurrencyCode: Text)
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);
        BankAcc.IBAN := IBANTxt;
        BankAcc."Currency Code" := CopyStr(BankAccCurrencyCode, 1, MaxStrLen(BankAcc."Currency Code"));
        BankAcc.Modify();

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), FileCurrencyCode, IBANTxt, Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        BankAccReconciliation.ImportBankStatement();
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyBankAccCurrencyDiffFromFileCurrency()
    begin
        // [SCENARIO 5] Import a bank statement file, where the currency of the transactions should be checked against the currency of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no. and currency code.
        // [GIVEN] A bank statement file for a bank account containing transactions with a different currency.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is an error informing the user that the currencies do not match.
        LibraryLowerPermissions.SetBanking();
        LibraryLowerPermissions.AddO365Setup();
        asserterror ImportFileForBankDataConvServWithCurrency(LibraryERM.CreateCurrencyWithExchangeRate(DMY2Date(1, 1, 2000), 1, 1),
            LibraryERM.CreateCurrencyWithExchangeRate(DMY2Date(1, 1, 2000), 1, 1));

        // Verify
        Assert.ExpectedError(BankAccCurrErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyBankAccCurrencyBlankDiffFromFileCurrencyNotLCY()
    begin
        // [SCENARIO 6] Import a bank statement file, where the currency of the transactions should be checked against the currency of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no. and currency code blank.
        // [GIVEN] A bank statement file for a bank account containing transactions with a given currency other than LCY.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is an error informing the user that the currencies do not match.
        LibraryLowerPermissions.SetBanking();
        LibraryLowerPermissions.AddO365Setup();
        asserterror ImportFileForBankDataConvServWithCurrency(LibraryERM.CreateCurrencyWithExchangeRate(DMY2Date(1, 1, 2000), 1, 1), '');

        // Verify
        Assert.ExpectedError(BankAccCurrErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyBankAccCurrencyBlankDiffFromFileCurrencyLCY()
    begin
        // [SCENARIO 7] Import a bank statement file, where the currency of the transactions should be checked against the currency of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no. and currency code blank.
        // [GIVEN] A bank statement file for a bank account containing transactions in LCY.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] Import is allowed.
        LibraryLowerPermissions.SetBanking();
        LibraryLowerPermissions.AddO365Setup();
        ImportFileForBankDataConvServWithCurrency(CurrTxt, '');
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyBankAccCurrencyDiffFromBlankFileCurrency()
    begin
        // [SCENARIO 8] Import a bank statement file, where the currency of the transactions should be checked against the currency of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no. and currency code.
        // [GIVEN] A bank statement file for a bank account containing transactions with a blank currency code.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] Import is allowed.
        LibraryLowerPermissions.SetBanking();
        LibraryLowerPermissions.AddO365Setup();
        ImportFileForBankDataConvServWithCurrency('', LibraryERM.CreateCurrencyWithExchangeRate(DMY2Date(1, 1, 2000), 1, 1));
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyBankAccCurrencyAndFileCurrencyAreBlank()
    begin
        // [SCENARIO 9] Import a bank statement file, where the currency of the transactions should be checked against the currency of my bank account.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no. and blank currency code.
        // [GIVEN] A bank statement file for a bank account containing transactions with a blank currency code.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] Import is allowed.
        LibraryLowerPermissions.SetBanking();
        LibraryLowerPermissions.AddO365Setup();
        ImportFileForBankDataConvServWithCurrency('', '');
    end;

    [Test]
    [Scope('OnPrem')]
    procedure VerifyMultiStatementForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 10] Import a bank statement file, that should not contain more than one statement.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no. and blank currency code.
        // [GIVEN] A bank statement file for a bank account containing more than one bank acc. statement.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] An error is thrown, informing the user about the multiple statements.
        Initialize();
        LibraryLowerPermissions.SetBanking();
        LibraryLowerPermissions.AddO365Setup();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify();

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), '', IBANTxt, Format(DMY2Date(1, 1, 2016), 0, 9),
          Format(150.75, 0, 9), 'EndBalance', 2);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        asserterror BankAccReconciliation.ImportBankStatement();

        Assert.ExpectedError(MultiStatementErr);
    end;

    [Test]
    [HandlerFunctions('MissingStmtDateMsgHandler')]
    [Scope('OnPrem')]
    procedure VerifyStmtDateMissingForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 11] Import a bank statement file, that should contain a statement date.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no..
        // [GIVEN] A bank statement file for a bank account that is missing a statement date.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is a message informing the user that the statement date is missing.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc."Bank Branch No." := Format(LibraryRandom.RandIntInRange(1111, 9999));
        BankAcc."Bank Account No." := LibraryUtility.GenerateGUID();
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, BankAcc."Bank Account No.", '', Format(150.75, 0, 9), 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify: In message handler.
    end;

    [Test]
    [HandlerFunctions('MissingStmtClosingBalanceTypeMsgHandler')]
    [Scope('OnPrem')]
    procedure VerifyStmtBalTypeMissingForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 12] Import a bank statement file, that should contain a statement end balance.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no..
        // [GIVEN] A bank statement file for a bank account that is missing a statement balance type tag.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is a message informing the user that the statement balance type is missing.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc."Bank Branch No." := Format(LibraryRandom.RandIntInRange(1111, 9999));
        BankAcc."Bank Account No." := LibraryUtility.GenerateGUID();
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, BankAcc."Bank Account No.",
          Format(DMY2Date(1, 1, 2016), 0, 9), Format(150.75, 0, 9), '', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify: In message handler.
    end;

    [Test]
    [HandlerFunctions('MissingStmtClosingBalanceMsgHandler')]
    [Scope('OnPrem')]
    procedure VerifyStmtBalAmountMissingForBankDataConvServ()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line";
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        // [SCENARIO 13] Import a bank statement file, that should contain a statement end balance.
        // [GIVEN] A bank account set up to import with the AMC format, with a given bank account no..
        // [GIVEN] A bank statement file for a bank account that is missing a statement balance amount.
        // [WHEN] Invoking the Import bank statement from the Bank Acc. Reconciliation page.
        // [THEN] There is a message informing the user that the statement balance amount is missing.
        Initialize();

        // Setup
        CreateBankAccWithBankStatementSetup(BankAcc, 'BANKDATACONVSERVSTMT');
        BankAcc."Bank Branch No." := Format(LibraryRandom.RandIntInRange(1111, 9999));
        BankAcc."Bank Account No." := LibraryUtility.GenerateGUID();
        BankAcc.Modify();

        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        CreateBankAccReconTemplateWithFilter(BankAccReconciliationLineTemplate, BankAccReconciliation);

        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteBankDataConvServResponse(OutStream, 'UstrdText', 'Address', 'GB', 'Name',
          Format(150.75, 0, 9), Format(DMY2Date(1, 1, 2016), 0, 9), CurrTxt, BankAcc."Bank Account No.",
          Format(DMY2Date(1, 1, 2016), 0, 9), '', 'EndBalance', 1);
        SetupSourceMock('BANKDATACONVSERVSTMT', TempBlobUTF8, '');

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.ImportBankStatement();

        // Verify: In message handler.
    end;

    [Test]
    [Scope('OnPrem')]
    procedure DeleteBankStatementDetails()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
    begin
        Initialize();

        // Setup.
        SetupBankAccRecForImport(BankAccReconciliation);
        BankAccReconciliation.ImportBankStatement();

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.Delete(true);

        // Verify.
        VerifyDataExchFieldIsDeleted(GetLastDataExch());
    end;

    [Test]
    [Scope('OnPrem')]
    procedure DeleteBankStatementDetailsForMultipleImports()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        EntryNo: Integer;
    begin
        Initialize();

        // Setup.
        SetupBankAccRecForImport(BankAccReconciliation);
        BankAccReconciliation.ImportBankStatement();
        EntryNo := GetLastDataExch();
        BankAccReconciliation.ImportBankStatement();

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliation.Delete(true);

        // Verify.
        VerifyDataExchFieldIsDeleted(EntryNo);
        VerifyDataExchFieldIsDeleted(GetLastDataExch());
    end;

    [Test]
    [Scope('OnPrem')]
    procedure DeleteBankStatementDetailsForMultipleImportsByLine()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line";
        EntryNo: Integer;
    begin
        Initialize();

        // Setup.
        SetupBankAccRecForImport(BankAccReconciliation);
        BankAccReconciliation.ImportBankStatement();
        EntryNo := GetLastDataExch();
        BankAccReconciliation.ImportBankStatement();

        // Exercise
        LibraryLowerPermissions.SetBanking();
        BankAccReconciliationLine.FilterBankRecLines(BankAccReconciliation);
        BankAccReconciliationLine.SetRange("Data Exch. Entry No.", EntryNo);
        BankAccReconciliationLine.DeleteAll(true);

        // Verify.
        VerifyDataExchFieldIsDeleted(EntryNo);
        VerifyDataExchFieldIsKept(GetLastDataExch());
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure DeleteBankStatementDetailsWhenPosting()
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
    begin
        Initialize();

        // Setup.
        SetupBankAccRecForImport(BankAccReconciliation);
        BankAccReconciliation.ImportBankStatement();
        ApplyBankRecLines(BankAccReconciliation);
        BankAccReconciliation.Find();
        BankAccReconciliation."Balance Last Statement" :=
          BankAccReconciliation."Statement Ending Balance" - GetTotalBalance(BankAccReconciliation);
        BankAccReconciliation.Modify();

        // Exercise
        LibraryLowerPermissions.SetBanking();
        CODEUNIT.Run(CODEUNIT::"Bank Acc. Reconciliation Post", BankAccReconciliation);

        // Verify.
        VerifyDataExchFieldIsDeleted(GetLastDataExch());
    end;

    [Normal]
    local procedure Initialize()
    begin
        LibraryVariableStorage.Clear();
        if IsInitialized then
            exit;

        CurrTxt := 'EUR';
        IBANTxt := '15415024154';
        LibraryERMCountryData.UpdateGeneralLedgerSetup();
        LibraryERM.SetLCYCode(CurrTxt);
        Commit();

        IsInitialized := true;
    end;

    local procedure WriteCAMTFile(OutStream: OutStream; Encoding: Text)
    begin
        CAMTFileWriter(OutStream, Encoding, true, true, true, true, true);
    end;

    local procedure WriteCAMTFileNoIBAN(OutStream: OutStream; Encoding: Text)
    begin
        CAMTFileWriter(OutStream, Encoding, false, true, true, true, true);
    end;

    local procedure WriteCAMTFileNoStatementDate(OutStream: OutStream; Encoding: Text)
    begin
        CAMTFileWriter(OutStream, Encoding, true, false, true, true, true);
    end;

    local procedure WriteCAMTFileNoBalType(OutStream: OutStream; Encoding: Text)
    begin
        CAMTFileWriter(OutStream, Encoding, true, true, false, true, true);
    end;

    local procedure WriteCAMTFileNoClosingBal(OutStream: OutStream; Encoding: Text)
    begin
        CAMTFileWriter(OutStream, Encoding, true, true, true, false, true);
    end;

    local procedure WriteCAMTFileNoCrdDbtInd(OutStream: OutStream; Encoding: Text)
    begin
        CAMTFileWriter(OutStream, Encoding, true, true, true, true, false);
    end;

    local procedure CAMTFileWriter(OutStream: OutStream; Encoding: Text; IncludeIBAN: Boolean; IncludeStatementDate: Boolean; IncludeBalType: Boolean; IncludeClosingBal: Boolean; IncludeCrdDbtInd: Boolean)
    var
        YearText: Text;
    begin
        YearText := Format(Date2DMY(WorkDate(), 3));
        WriteLine(OutStream, '<?xml version="1.0" encoding="' + Encoding + '"?>');
        WriteLine(OutStream,
          '<Document xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="' + NamespaceTxt + '">');
        WriteLine(OutStream, '  <BkToCstmrStmt>');
        WriteLine(OutStream, '    <GrpHdr>');
        WriteLine(OutStream, '      <MsgId>FP-STAT001</MsgId>');
        WriteLine(OutStream, '    </GrpHdr>');
        WriteLine(OutStream, '    <Stmt>');
        WriteLine(OutStream, '      <Id>FP-STAT001</Id>');
        if IncludeStatementDate then
            WriteLine(OutStream, StrSubstNo('      <CreDtTm>%1-06-06T17:00:00+01:00</CreDtTm>', YearText));
        WriteLine(OutStream, '      <Acct>');
        WriteLine(OutStream, '        <Id>');
        if IncludeIBAN then
            WriteLine(OutStream, '          <IBAN>' + IBANTxt + '</IBAN>');
        WriteLine(OutStream, '        </Id>');
        WriteLine(OutStream, '      </Acct>');
        WriteLine(OutStream, '      <Bal>');
        WriteLine(OutStream, '        <Tp>');
        WriteLine(OutStream, '          <CdOrPrtry>');
        WriteLine(OutStream, '            <Cd>OPBD</Cd>');
        WriteLine(OutStream, '          </CdOrPrtry>');
        WriteLine(OutStream, '        </Tp>');
        WriteLine(OutStream, '      <Amt Ccy="' + CurrTxt + '">500000</Amt>');
        WriteLine(OutStream, '      <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '      <Dt>');
        WriteLine(OutStream, StrSubstNo('        <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '      </Dt>');
        WriteLine(OutStream, '      </Bal>');
        WriteLine(OutStream, '      <Bal>');
        WriteLine(OutStream, '        <Tp>');
        WriteLine(OutStream, '          <CdOrPrtry>');
        if IncludeBalType then
            WriteLine(OutStream, '            <Cd>CLBD</Cd>');
        WriteLine(OutStream, '          </CdOrPrtry>');
        WriteLine(OutStream, '        </Tp>');
        if IncludeClosingBal then
            WriteLine(OutStream, '      <Amt Ccy="' + CurrTxt + '">435678.50</Amt>');
        if IncludeCrdDbtInd then
            WriteLine(OutStream, '      <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '      <Dt>');
        WriteLine(OutStream, StrSubstNo('        <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '      </Dt>');
        WriteLine(OutStream, '      </Bal>');
        WriteLine(OutStream, '      <Ntry>');
        WriteLine(OutStream, '        <Amt Ccy="' + CurrTxt + '">105678.50</Amt>');
        WriteLine(OutStream, '        <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '        <Sts>BOOK</Sts>');
        WriteLine(OutStream, '        <BookgDt>');
        WriteLine(OutStream, StrSubstNo('          <DtTm>%1-01-01T13:15:00+01:00</DtTm>', YearText));
        WriteLine(OutStream, '        </BookgDt>');
        WriteLine(OutStream, '        <ValDt>');
        WriteLine(OutStream, StrSubstNo('          <Dt>%1-03-03</Dt>', YearText));
        WriteLine(OutStream, '        </ValDt>');
        WriteLine(OutStream, '        <AcctSvcrRef>FP-CN_98765/01</AcctSvcrRef>');
        WriteLine(OutStream, '        <NtryDtls>');
        WriteLine(OutStream, '          <TxDtls>');
        WriteLine(OutStream, '            <RltdPties>');
        WriteLine(OutStream, '              <Dbtr>');
        WriteLine(OutStream, '                <Nm>Cronus Ltd.</Nm>');
        WriteLine(OutStream, '              </Dbtr>');
        WriteLine(OutStream, '            </RltdPties>');
        WriteLine(OutStream, '          </TxDtls>');
        WriteLine(OutStream, '        </NtryDtls>');
        WriteLine(OutStream, '      </Ntry>');
        WriteLine(OutStream, '      <Ntry>');
        WriteLine(OutStream, '        <Amt Ccy="' + CurrTxt + '">105.42</Amt>');
        WriteLine(OutStream, '        <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '        <Sts>BOOK2</Sts>');
        WriteLine(OutStream, '        <BookgDt>');
        WriteLine(OutStream, StrSubstNo('          <DtTm>%1-03-03T13:15:00+01:00</DtTm>', YearText));
        WriteLine(OutStream, '        </BookgDt>');
        WriteLine(OutStream, '        <ValDt>');
        WriteLine(OutStream, StrSubstNo('          <DtTm>%1-05-05T13:15:00+01:00</DtTm>', YearText));
        WriteLine(OutStream, '        </ValDt>');
        WriteLine(OutStream, '        <AcctSvcrRef>FP-CN_3321d3/0/2</AcctSvcrRef>');
        WriteLine(OutStream, '        <NtryDtls>');
        WriteLine(OutStream, '          <TxDtls>');
        WriteLine(OutStream, '            <RltdPties>');
        WriteLine(OutStream, '              <Dbtr>');
        WriteLine(OutStream, '                <Nm>Payer 1234</Nm>');
        WriteLine(OutStream, '              </Dbtr>');
        WriteLine(OutStream, '            </RltdPties>');
        WriteLine(OutStream, '          </TxDtls>');
        WriteLine(OutStream, '        </NtryDtls>');
        WriteLine(OutStream, '      </Ntry>');
        WriteLine(OutStream, '    </Stmt>');
        WriteLine(OutStream, '  </BkToCstmrStmt>');
        WriteLine(OutStream, '</Document>');
    end;

    local procedure WriteBankDataConvServResponse(OutStream: OutStream; UstrdTxt: Text; Address: Text; CountryIso: Text; Name: Text; Amount: Text; Date: Text; CurrencyCode: Text; BankAccNo: Text; StmtDate: Text; StmtAmount: Text; BalType: Text; StatementCount: Integer)
    var
        AmcBankingMgt: Codeunit "AMC Banking Mgt.";
        "count": Integer;
    begin
        WriteLine(OutStream, '    <ns2:reportExportResponse xmlns:ns2="' + AmcBankingMgt.GetNamespace() + '">');
        WriteLine(OutStream, '      <return>');

        for count := 1 to StatementCount do
            WriteBankDataConvServStmtElement(OutStream, UstrdTxt, Address, CountryIso, Name, Amount, Date, CurrencyCode, BankAccNo, StmtDate,
              StmtAmount, BalType);

        WriteLine(OutStream, '      </return>');
        WriteLine(OutStream, '      </ns2:reportExportResponse>');
    end;

    local procedure WriteBankDataConvServStmtElement(OutStream: OutStream; UstrdTxt: Text; Address: Text; CountryIso: Text; Name: Text; Amount: Text; Date: Text; CurrencyCode: Text; BankAccNo: Text; StmtDate: Text; StmtAmount: Text; BalType: Text)
    begin
        WriteLine(OutStream, '        <finsta>');
        WriteLine(OutStream, '          <transactions>');
        WriteLine(OutStream, '            <originalreceiversref>' + UstrdTxt + '</originalreceiversref>');
        WriteLine(OutStream, '            <message>');
        WriteLine(OutStream, '              <linenum>1</linenum>');
        WriteLine(OutStream, '              <text>' + UstrdTxt + '</text>');
        WriteLine(OutStream, '            </message>');
        WriteLine(OutStream, '            <senderpartyidentification>');
        WriteLine(OutStream, '              <address1>' + Address + '</address1>');
        WriteLine(OutStream, '              <countryisocode>' + CountryIso + '</countryisocode>');
        WriteLine(OutStream, '              <name>' + Name + '</name>');
        WriteLine(OutStream, '            </senderpartyidentification>');
        WriteLine(OutStream, '            <posting>');
        WriteLine(OutStream, '              <amount>' + Amount + '</amount>');
        WriteLine(OutStream, '              <currency>' + CurrencyCode + '</currency>');
        WriteLine(OutStream, '              <date>' + Date + '</date>');
        WriteLine(OutStream, '            </posting>');
        WriteLine(OutStream, '            <amountdetails>');
        WriteLine(OutStream, '              <currency>' + CurrencyCode + '</currency>');
        WriteLine(OutStream, '              <date>' + Date + '</date>');
        WriteLine(OutStream, '              <type></type>');
        WriteLine(OutStream, '              <value></value>');
        WriteLine(OutStream, '            </amountdetails>');
        WriteLine(OutStream, '          </transactions>');
        WriteLine(OutStream, '          <ownbankaccountidentification>');
        WriteLine(OutStream, '            <bankaccount>' + BankAccNo + '</bankaccount>');
        WriteLine(OutStream, '            <currency>' + CurrencyCode + '</currency>');
        WriteLine(OutStream, '            <swiftcode></swiftcode>');
        WriteLine(OutStream, '          </ownbankaccountidentification>');
        WriteLine(OutStream, '          <statementdetails>');
        WriteLine(OutStream, '            <fromdate>' + Date + '</fromdate>');
        WriteLine(OutStream, '            <statementno>1234</statementno>');
        WriteLine(OutStream, '            <todate>' + StmtDate + '</todate>');
        WriteLine(OutStream, '            <amountdetails>');
        WriteLine(OutStream, '              <currency>' + CurrencyCode + '</currency>');
        WriteLine(OutStream, '              <date>' + Date + '</date>');
        WriteLine(OutStream, '              <type>StartBalance</type>');
        WriteLine(OutStream, '              <value>0</value>');
        WriteLine(OutStream, '            </amountdetails>');
        WriteLine(OutStream, '            <amountdetails>');
        WriteLine(OutStream, '              <currency>' + CurrencyCode + '</currency>');
        WriteLine(OutStream, '              <date>' + StmtDate + '</date>');
        WriteLine(OutStream, '              <type>' + BalType + '</type>');
        WriteLine(OutStream, '              <value>' + StmtAmount + '</value>');
        WriteLine(OutStream, '            </amountdetails>');
        WriteLine(OutStream, '            </statementdetails>');
        WriteLine(OutStream, '          </finsta>');
    end;

    local procedure WriteMultiStatementCAMTFile(OutStream: OutStream; Encoding: Text)
    var
        YearText: Text;
    begin
        YearText := Format(Date2DMY(WorkDate(), 3));
        WriteLine(OutStream, '<?xml version="1.0" encoding="' + Encoding + '"?>');
        WriteLine(OutStream,
          '<Document xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="' + NamespaceTxt + '">');
        WriteLine(OutStream, '  <BkToCstmrStmt>');
        WriteLine(OutStream, '    <GrpHdr>');
        WriteLine(OutStream, '      <MsgId>FP-STAT001</MsgId>');
        WriteLine(OutStream, '    </GrpHdr>');
        WriteLine(OutStream, '    <Stmt>');
        WriteLine(OutStream, '      <Id>FP-STAT001</Id>');
        WriteLine(OutStream, StrSubstNo('      <CreDtTm>%1-05-05T17:00:00+01:00</CreDtTm>', YearText));
        WriteLine(OutStream, '      <Acct>');
        WriteLine(OutStream, '        <Id>');
        WriteLine(OutStream, '          <IBAN>' + IBANTxt + '</IBAN>');
        WriteLine(OutStream, '        </Id>');
        WriteLine(OutStream, '      </Acct>');
        WriteLine(OutStream, '      <Bal>');
        WriteLine(OutStream, '        <Tp>');
        WriteLine(OutStream, '          <CdOrPrtry>');
        WriteLine(OutStream, '            <Cd>OPBD</Cd>');
        WriteLine(OutStream, '          </CdOrPrtry>');
        WriteLine(OutStream, '        </Tp>');
        WriteLine(OutStream, '      <Amt Ccy="' + CurrTxt + '">500000</Amt>');
        WriteLine(OutStream, '      <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '      <Dt>');
        WriteLine(OutStream, StrSubstNo('        <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '      </Dt>');
        WriteLine(OutStream, '      </Bal>');
        WriteLine(OutStream, '      <Bal>');
        WriteLine(OutStream, '        <Tp>');
        WriteLine(OutStream, '          <CdOrPrtry>');
        WriteLine(OutStream, '            <Cd>CLBD</Cd>');
        WriteLine(OutStream, '          </CdOrPrtry>');
        WriteLine(OutStream, '        </Tp>');
        WriteLine(OutStream, '      <Amt Ccy="' + CurrTxt + '">435678.50</Amt>');
        WriteLine(OutStream, '      <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '      <Dt>');
        WriteLine(OutStream, StrSubstNo('        <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '      </Dt>');
        WriteLine(OutStream, '      </Bal>');
        WriteLine(OutStream, '      <Ntry>');
        WriteLine(OutStream, '        <Amt Ccy="' + CurrTxt + '">105678.50</Amt>');
        WriteLine(OutStream, '        <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '        <Sts>BOOK</Sts>');
        WriteLine(OutStream, '        <BookgDt>');
        WriteLine(OutStream, StrSubstNo('          <DtTm>%1-05-05T13:15:00+01:00</DtTm>', YearText));
        WriteLine(OutStream, '        </BookgDt>');
        WriteLine(OutStream, '        <ValDt>');
        WriteLine(OutStream, StrSubstNo('          <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '        </ValDt>');
        WriteLine(OutStream, '        <AcctSvcrRef>FP-CN_98765/01</AcctSvcrRef>');
        WriteLine(OutStream, '      </Ntry>');
        WriteLine(OutStream, '    </Stmt>');
        WriteLine(OutStream, '    <Stmt>');
        WriteLine(OutStream, '      <Id>FP-STAT002</Id>');
        WriteLine(OutStream, StrSubstNo('      <CreDtTm>%1-05-05T17:00:00+01:00</CreDtTm>', YearText));
        WriteLine(OutStream, '      <Acct>');
        WriteLine(OutStream, '        <Id>');
        WriteLine(OutStream, '          <IBAN>' + IBANTxt + '</IBAN>');
        WriteLine(OutStream, '        </Id>');
        WriteLine(OutStream, '      </Acct>');
        WriteLine(OutStream, '      <Bal>');
        WriteLine(OutStream, '        <Tp>');
        WriteLine(OutStream, '          <CdOrPrtry>');
        WriteLine(OutStream, '            <Cd>OPBD</Cd>');
        WriteLine(OutStream, '          </CdOrPrtry>');
        WriteLine(OutStream, '        </Tp>');
        WriteLine(OutStream, '      <Amt Ccy="' + CurrTxt + '">500000</Amt>');
        WriteLine(OutStream, '      <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '      <Dt>');
        WriteLine(OutStream, StrSubstNo('        <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '      </Dt>');
        WriteLine(OutStream, '      </Bal>');
        WriteLine(OutStream, '      <Bal>');
        WriteLine(OutStream, '        <Tp>');
        WriteLine(OutStream, '          <CdOrPrtry>');
        WriteLine(OutStream, '            <Cd>CLBD</Cd>');
        WriteLine(OutStream, '          </CdOrPrtry>');
        WriteLine(OutStream, '        </Tp>');
        WriteLine(OutStream, '      <Amt Ccy="' + CurrTxt + '">435678.50</Amt>');
        WriteLine(OutStream, '      <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '      <Dt>');
        WriteLine(OutStream, StrSubstNo('        <Dt>%1-05-05</Dt>', YearText));
        WriteLine(OutStream, '      </Dt>');
        WriteLine(OutStream, '      </Bal>');
        WriteLine(OutStream, '      <Ntry>');
        WriteLine(OutStream, '        <Amt Ccy="' + CurrTxt + '">105678.50</Amt>');
        WriteLine(OutStream, '        <CdtDbtInd>CRDT</CdtDbtInd>');
        WriteLine(OutStream, '        <Sts>BOOK</Sts>');
        WriteLine(OutStream, '        <BookgDt>');
        WriteLine(OutStream, StrSubstNo('          <DtTm>%1-05-05T13:15:00+01:00</DtTm>', YearText));
        WriteLine(OutStream, '        </BookgDt>');
        WriteLine(OutStream, '        <ValDt>');
        WriteLine(OutStream, StrSubstNo('          <Dt>%1-04-04</Dt>', YearText));
        WriteLine(OutStream, '        </ValDt>');
        WriteLine(OutStream, '        <AcctSvcrRef>FP-CN_98765/01</AcctSvcrRef>');
        WriteLine(OutStream, '      </Ntry>');
        WriteLine(OutStream, '    </Stmt>');
        WriteLine(OutStream, '  </BkToCstmrStmt>');
        WriteLine(OutStream, '</Document>');
    end;

    local procedure WriteLine(OutStream: OutStream; Text: Text)
    begin
        OutStream.WriteText(Text);
        OutStream.WriteText();
    end;

    local procedure SetupSourceMock(DataExchDefCode: Code[20]; TempBlob: Codeunit "Temp Blob"; Namespace: Text)
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchLineDef: Record "Data Exch. Line Def";
        ErmPeSourceTestMock: Codeunit "ERM PE Source Test Mock";
        TempBlobList: Codeunit "Temp Blob List";
    begin
        TempBlobList.Add(TempBlob);
        ErmPeSourceTestMock.SetTempBlobList(TempBlobList);

        DataExchDef.Get(DataExchDefCode);
        DataExchDef."Ext. Data Handling Codeunit" := CODEUNIT::"ERM PE Source Test Mock";
        DataExchDef.Modify();

        DataExchLineDef.SetRange("Data Exch. Def Code", DataExchDefCode);
        DataExchLineDef.FindFirst();
        DataExchLineDef.Namespace := CopyStr(Namespace, 1, MaxStrLen(DataExchLineDef.Namespace));
        DataExchLineDef.Modify();
    end;

    local procedure SetupBankAccRecForImport(var BankAccReconciliation: Record "Bank Acc. Reconciliation")
    var
        BankAcc: Record "Bank Account";
        TempBlobUTF8: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        TempBlobUTF8.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        WriteCAMTFile(OutStream, 'UTF-8');

        SetupSourceMock('SEPA CAMT', TempBlobUTF8, NamespaceTxt);
        CreateBankAccWithBankStatementSetup(BankAcc, 'SEPA CAMT');
        LibraryERM.CreateBankAccReconciliation(BankAccReconciliation, BankAcc."No.",
          BankAccReconciliation."Statement Type"::"Bank Reconciliation");
        BankAcc.IBAN := IBANTxt;
        BankAcc.Modify(true);
    end;

    local procedure CreateBankAccReconTemplateWithFilter(var BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line"; BankAccReconciliation: Record "Bank Acc. Reconciliation")
    begin
        LibraryERM.CreateBankAccReconciliationLn(BankAccReconciliationLineTemplate, BankAccReconciliation);

        BankAccReconciliationLineTemplate.Delete(true); // The template needs to removed to not skew when comparing testresults.
        BankAccReconciliationLineTemplate.SetRange("Statement Type", BankAccReconciliation."Statement Type");
        BankAccReconciliationLineTemplate.SetRange("Bank Account No.", BankAccReconciliation."Bank Account No.");
        BankAccReconciliationLineTemplate.SetRange("Statement No.", BankAccReconciliation."Statement No.");
    end;

    local procedure CreateLineExt(var TempBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line" temporary; BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line"; DataExchEntryNo: Integer; DataExchLineNo: Integer; LineNo: Integer; TransactionDate: Date; ValueDate: Date; Description: Text[50]; PayerInfo: Text[50]; TransactionInfo: Text[50]; Amount: Decimal; Address: Text[100])
    begin
        TempBankAccReconciliationLine.Copy(BankAccReconciliationLineTemplate);
        TempBankAccReconciliationLine.Validate("Data Exch. Entry No.", DataExchEntryNo);
        TempBankAccReconciliationLine.Validate("Data Exch. Line No.", DataExchLineNo);
        TempBankAccReconciliationLine.Validate("Statement Line No.", LineNo);
        TempBankAccReconciliationLine.Validate("Transaction Date", TransactionDate);
        TempBankAccReconciliationLine.Validate(Description, Description);
        TempBankAccReconciliationLine.Validate("Related-Party Name", PayerInfo);
        TempBankAccReconciliationLine.Validate("Additional Transaction Info", TransactionInfo);
        TempBankAccReconciliationLine.Validate("Transaction Text", TransactionInfo);
        TempBankAccReconciliationLine.Validate("Statement Amount", Amount);
        TempBankAccReconciliationLine.Validate("Value Date", ValueDate);
        TempBankAccReconciliationLine.Validate("Related-Party Address", Address);
        TempBankAccReconciliationLine.Insert();
    end;

    local procedure CreateLine(var TempBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line" temporary; BankAccReconciliationLineTemplate: Record "Bank Acc. Reconciliation Line"; DataExchEntryNo: Integer; DataExchLineNo: Integer; LineNo: Integer; TransactionDate: Date; ValueDate: Date; Description: Text[50]; PayerInfo: Text[50]; TransactionInfo: Text[50]; Amount: Decimal; Address: Text[100])
    begin
        CreateLineExt(TempBankAccReconciliationLine, BankAccReconciliationLineTemplate, DataExchEntryNo,
          DataExchLineNo, LineNo, TransactionDate, ValueDate, Description, PayerInfo, TransactionInfo, Amount, Address);
    end;

    local procedure CreateBankAccWithBankStatementSetup(var BankAccount: Record "Bank Account"; DataExchDefCode: Code[20])
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
    begin
        BankExportImportSetup.Init();
        BankExportImportSetup.Code :=
          LibraryUtility.GenerateRandomCode(BankExportImportSetup.FieldNo(Code), DATABASE::"Bank Export/Import Setup");
        BankExportImportSetup.Direction := BankExportImportSetup.Direction::Import;
        if DataExchDefCode <> '' then
            BankExportImportSetup."Data Exch. Def. Code" := DataExchDefCode;
        BankExportImportSetup.Insert();

        LibraryERM.CreateBankAccount(BankAccount);
        BankAccount.Validate("Last Statement No.",
          LibraryUtility.GenerateRandomCode(BankAccount.FieldNo("Last Statement No."), DATABASE::"Bank Account"));
        BankAccount."Bank Statement Import Format" := BankExportImportSetup.Code;
        BankAccount.Modify(true);
    end;

    local procedure AssertDataInTable(var TempExpectedBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line" temporary; var ActualBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line"; Msg: Text)
    var
        LineNo: Integer;
    begin
        TempExpectedBankAccReconciliationLine.FindFirst();
        ActualBankAccReconciliationLine.FindFirst();
        repeat
            LineNo += 1;
            AreEqualRecords(TempExpectedBankAccReconciliationLine, ActualBankAccReconciliationLine, Msg + 'Line:' + Format(LineNo) + ' ');
        until (TempExpectedBankAccReconciliationLine.Next() = 0) or (ActualBankAccReconciliationLine.Next() = 0);
        Assert.AreEqual(TempExpectedBankAccReconciliationLine.Count(), ActualBankAccReconciliationLine.Count(), 'Row count does not match');
    end;

    local procedure AreEqualRecords(ExpectedRecord: Variant; ActualRecord: Variant; Msg: Text)
    var
        ExpectedRecRef: RecordRef;
        ActualRecRef: RecordRef;
        i: Integer;
    begin
        ExpectedRecRef.GetTable(ExpectedRecord);
        ActualRecRef.GetTable(ActualRecord);

        Assert.AreEqual(ExpectedRecRef.Number(), ActualRecRef.Number(), 'Tables are not the same');

        for i := 1 to ExpectedRecRef.FieldCount() do
            if IsSupportedType(ExpectedRecRef.FieldIndex(i).Value()) then
                Assert.AreEqual(ExpectedRecRef.FieldIndex(i).Value(), ActualRecRef.FieldIndex(i).Value(),
                  StrSubstNo(AssertMsg, Msg, ExpectedRecRef.FieldIndex(i).Name()));
    end;

    local procedure IsSupportedType(Value: Variant): Boolean
    begin
        exit(Value.IsBoolean() or
          Value.IsOption() or
          Value.IsInteger() or
          Value.IsDecimal() or
          Value.IsText() or
          Value.IsCode() or
          Value.IsDate() or
          Value.IsTime());
    end;

    local procedure GetTotalBalance(BankAccReconciliation: Record "Bank Acc. Reconciliation"): Decimal
    var
        BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line";
    begin
        with BankAccReconciliationLine do begin
            FilterBankRecLines(BankAccReconciliation);
            CalcSums("Statement Amount");
            exit("Statement Amount");
        end;
    end;

    local procedure GetLastDataExch(): Integer
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch.SetRange("Data Exch. Def Code", 'SEPA CAMT');
        DataExch.FindLast();
        exit(DataExch."Entry No.");
    end;

    local procedure ApplyBankRecLines(var BankAccReconciliation: Record "Bank Acc. Reconciliation")
    var
        BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line";
        GenJournalLine: Record "Gen. Journal Line";
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
        GLAccount: Record "G/L Account";
    begin
        LibraryERM.CreateGenJournalTemplate(GenJournalTemplate);
        LibraryERM.FindGLAccount(GLAccount);

        if BankAccReconciliationLine.LinesExist(BankAccReconciliation) then
            repeat
                LibraryERM.CreateGenJournalBatch(GenJournalBatch, GenJournalTemplate.Name);
                LibraryERM.CreateGeneralJnlLine(GenJournalLine, GenJournalTemplate.Name, GenJournalBatch.Name,
                  GenJournalLine."Document Type"::Payment, GenJournalLine."Account Type"::"Bank Account",
                  BankAccReconciliationLine."Bank Account No.", BankAccReconciliationLine."Statement Amount");
                GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
                GenJournalLine.Validate("Bal. Account No.", GLAccount."No.");
                GenJournalLine.Validate("Posting Date", BankAccReconciliationLine."Transaction Date");
                GenJournalLine.Modify(true);
                LibraryERM.PostGeneralJnlLine(GenJournalLine);
            until BankAccReconciliationLine.Next() = 0;

        BankAccReconciliation.MatchSingle(0);
    end;

    local procedure VerifyBankAccRec(var BankAccReconciliation: Record "Bank Acc. Reconciliation"; StatementDate: Date; StatementEndingBalance: Decimal)
    begin
        BankAccReconciliation.Find();
        BankAccReconciliation.TestField("Statement Date", StatementDate);
        BankAccReconciliation.TestField("Statement Ending Balance", StatementEndingBalance);
    end;

    local procedure VerifyDataExchFieldIsDeleted(ExchNo: Integer)
    var
        DataExchField: Record "Data Exch. Field";
    begin
        DataExchField.SetRange("Data Exch. No.", ExchNo);
        Assert.IsTrue(DataExchField.IsEmpty(), 'There should be no remaining related info.');
    end;

    local procedure VerifyDataExchFieldIsKept(ExchNo: Integer)
    var
        DataExchField: Record "Data Exch. Field";
    begin
        DataExchField.SetRange("Data Exch. No.", ExchNo);
        Assert.IsFalse(DataExchField.IsEmpty(), 'The related info should not be deleted.');
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure MissingBankAccNoConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    var
        BankAccNo: Variant;
    begin
        LibraryVariableStorage.Dequeue(BankAccNo);
        Assert.AreEqual(StrSubstNo(MissingBankAccNoQst, BankAccNo), Question, 'Unexpected confirm dialog:' + Question);
        Reply := false;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MissingStmtDateMsgHandler(Message: Text[1024])
    begin
        Assert.ExpectedMessage(MissingStatementDateInDataMsg, Message);
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MissingStmtClosingBalanceTypeMsgHandler(Message: Text[1024])
    begin
        Assert.ExpectedMessage(MissingBalTypeInDataMsg, Message);
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MissingStmtClosingBalanceMsgHandler(Message: Text[1024])
    begin
        Assert.ExpectedMessage(MissingClosingBalanceInDataMsg, Message);
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure WrongBankAccNoConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    var
        BankAccNo: Variant;
    begin
        LibraryVariableStorage.Dequeue(BankAccNo);
        Assert.IsTrue(StrPos(Question, StrSubstNo(BankAccMismatchQst, BankAccNo)) > 0, 'Unexpected question:' + Question);
        Reply := true;
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure ConfirmHandlerYes(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
