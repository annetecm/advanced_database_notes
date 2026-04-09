
CREATE OR REPLACE TRIGGER TRG_BI_PET_CARE_LOG
BEFORE INSERT ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    -- Assign current date and time
    :NEW.LAST_UPDATE_DATETIME := SYSDATE;
    
    -- Assign current user
    :NEW.CREATED_BY_USER := USER;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Error in TRG_BI_PET_CARE_LOG: ' || SQLERRM
        );
END;
/

-- Second

CREATE OR REPLACE TRIGGER TRG_BU_PET_CARE_LOG
BEFORE UPDATE ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    -- Check if the current user matches the one in the row
    IF :OLD.CREATED_BY_USER != USER THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Update not allowed: user does not match the record owner.'
        );
    END IF;

    -- If allowed, update the timestamp
    :NEW.LAST_UPDATE_DATETIME := SYSDATE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Error in TRG_BU_PET_CARE_LOG: ' || SQLERRM
        );
END;
/

-- Third

CREATE OR REPLACE TRIGGER TRG_BD_PET_CARE_LOG
BEFORE DELETE ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    -- Allow delete only for specific user
    IF USER != 'JOEMANAGER' THEN
        RAISE_APPLICATION_ERROR(
            -20004,
            'Delete not allowed: only JOEMANAGER can delete records.'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'Error in TRG_BD_PET_CARE_LOG: ' || SQLERRM
        );
END;
/