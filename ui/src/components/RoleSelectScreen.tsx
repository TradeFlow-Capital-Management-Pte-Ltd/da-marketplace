import React, { useState} from 'react'
import { useHistory } from 'react-router-dom'
import { Button, Card } from 'semantic-ui-react'

import { useParty, useStreamQuery, useLedger } from '@daml/react'
import { useWellKnownParties } from '@daml/dabl-react'
import { UserSession } from '@daml.js/da-marketplace/lib/Marketplace/Onboarding'

import TopMenu from './common/TopMenu'
import OnboardingTile from './common/OnboardingTile'
import { ArrowRightIcon } from '../icons/Icons'

import './RoleSelectScreen.css'

enum MarketRole {
    INVESTOR = "Investor",
    ISSUER = "Issuer",
    CUSTODIAN = "Custodian"
}

type RoleSelectProps = {
    loading: boolean;
    caption: string;
    disabled?: boolean;
    roleSelectClick: () => void;
}

const RoleSelect: React.FC<RoleSelectProps> = ({ loading, disabled, caption, roleSelectClick }) => (
    <Card className='role-select centered'>
        <Button
            className='ghost'
            disabled={disabled}
            loading={loading}
            onClick={roleSelectClick}
        >
            { caption } <ArrowRightIcon/>
        </Button>
    </Card>
)

type Props = {
    onLogout: () => void;
}

const RoleSelectScreen: React.FC<Props> = ({ onLogout }) => {
    const history = useHistory();
    const [ loading, setLoading ] = useState(false);
    const [ role, setRole ] = useState<MarketRole>();

    const user = useParty();
    const ledger = useLedger();
    const operator = useWellKnownParties().userAdminParty;
    const userSessions = useStreamQuery(UserSession).contracts;

    const handleRoleClick = async (role: MarketRole) => {
        setRole(role);

        // don't create a new userSession if one exists
        if (userSessions.length === 0) {
            setLoading(true);
            await ledger.create(UserSession, { user, role, operator });
        }

        setLoading(false);
        setRole(undefined);
        history.push(`/role/${role.toLowerCase()}`);
    }

    return (
        <>
            <TopMenu onLogout={onLogout}/>
            <OnboardingTile subtitle='What will you do?'>
                <RoleSelect
                    caption='I want to chat & invest'
                    loading={loading && role === MarketRole.INVESTOR}
                    roleSelectClick={() => handleRoleClick(MarketRole.INVESTOR)}/>

                <RoleSelect
                    caption='Issue an asset'
                    loading={loading && role === MarketRole.ISSUER}
                    roleSelectClick={() => handleRoleClick(MarketRole.ISSUER)}/>

                {/* disabled these buttons until the view components for them are ready */}

                <RoleSelect
                    disabled
                    caption='Bank'
                    loading={loading && role === MarketRole.CUSTODIAN}
                    roleSelectClick={() => {}}/>
            </OnboardingTile>
        </>
    );
}

export default RoleSelectScreen;