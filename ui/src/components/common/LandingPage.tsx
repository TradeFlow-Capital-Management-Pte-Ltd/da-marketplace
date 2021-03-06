import React from 'react'
import { Header } from 'semantic-ui-react'

import Page from './Page'
import PageSection from './PageSection'
import WelcomeHeader from './WelcomeHeader'

import "./LandingPage.scss"

type Props = {
    profile?: React.ReactElement;
    marketRelationships?: React.ReactElement;
    sideNav: React.ReactElement;
    notifications?: React.ReactElement[];
    onLogout: () => void;
}

const LandingPage: React.FC<Props> = ({
    profile,
    marketRelationships,
    sideNav,
    notifications,
    onLogout
}) => (
    <Page
        sideNav={sideNav}
        onLogout={onLogout}
        menuTitle={<WelcomeHeader/>}
        notifications={notifications}
    >
        <PageSection>
            <div className='landing-page'>
                <div className='landing-page-column profile'>
                    <Header as='h3'>Profile</Header>
                    { profile }
                </div>

                <div className='landing-page-column market-relationships'>
                    <Header as='h3'>Market Relationships</Header>
                    { marketRelationships }
                </div>
            </div>
        </PageSection>
    </Page>
)

export default LandingPage;
