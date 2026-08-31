import { Building2 } from 'lucide-react'

import TabbedModulePage, { PlannedModuleContent } from '../../components/game/TabbedModulePage'

export default function TennisClubPage() {
  return (
    <TabbedModulePage
      title="Tennis Club"
      subtitle="Shared social club for ATP and WTA managers"
      eyebrow="Community competition"
      intro="Tennis Clubs are the one shared competitive-social layer where ATP and WTA professionals may belong to the same club. Singles tours, rankings, tournaments and matches remain completely separate."
      icon={<Building2 size={18} />}
      sideTitle="Club system pending"
      sideDescription="Club creation, invitations, combined club points and private club chat will be added as a dedicated shared-world system without merging ATP and WTA competition."
      tabs={[
        {
          id: 'members',
          label: 'Members',
          content: (
            <PlannedModuleContent
              title="Club membership"
              description="Create or join a named club and manage the ATP and WTA professionals who belong to it."
              items={[
                'Create a club and choose its name',
                'Invite managers to join',
                'View ATP and WTA members together',
                'Member roles and club administration',
                'Combined member contribution points',
              ]}
            />
          ),
        },
        {
          id: 'world-ranking',
          label: 'World Clubs',
          content: (
            <PlannedModuleContent
              title="World club ranking"
              description="Rank clubs by the combined official ATP and WTA ranking-point contributions of their members."
              items={[
                'Combined club points',
                'World club position',
                'Member point contribution breakdown',
                'Club ranking history',
                'Pagination and club search',
              ]}
            />
          ),
        },
        {
          id: 'chat',
          label: 'Club Chat',
          content: (
            <PlannedModuleContent
              title="Private club conversation"
              description="Give members one shared space for conversation, planning and community interaction."
              items={[
                'Club-only chat',
                'Message history',
                'Basic moderation controls',
                'Member join/leave notices',
                'Unread message indicator',
              ]}
            />
          ),
        },
      ]}
    />
  )
}
