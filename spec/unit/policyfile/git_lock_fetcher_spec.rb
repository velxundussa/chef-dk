#
# Copyright:: Copyright (c) 2017 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "spec_helper"
require "chef-dk/policyfile/git_lock_fetcher"

describe ChefDK::Policyfile::GitLockFetcher do

  let(:revision_id) { "6fe753184c8946052d3231bb4212116df28d89a3a5f7ae52832ad408419dd5eb" }
  let(:identifier) { "fab501cfaf747901bd82c1bc706beae7dc3a350c" }
  let(:git_revision) { "8404a9e0b5c27c55d529e61222e14f950b6e4171" }
  let(:rel) { "cookbooks/nested_cookbook" }
  let(:cookbook_name) {"git-cookbook"}
  let(:nested_cookbook_name) {"cookbooks/nested-cookbook"}
  let(:repo) { "https://github.com/monkeynews/bananas" }

  let(:minimal_lockfile_json) do
    <<-E
{
  "revision_id": "#{revision_id}",
  "name": "install-example",
  "run_list": [
    "recipe[#{cookbook_name}::default]"
  ],
  "cookbook_locks": {
    "#{cookbook_name}": {
      "version": "2.3.4",
      "identifier": "#{identifier}",
      "dotted_decimal_identifier": "70567763561641081.489844270461035.258281553147148",
      "cache_key": "#{cookbook_name}-#{git_revision}",
      "source_options": {
        "git": "#{repo}",
        "revision": "#{git_revision}"
      }
    }
  },
  "default_attributes": {},
  "override_attributes": {},
  "solution_dependencies": {
    "Policyfile": [
      [
        "#{cookbook_name}",
        ">= 0.0.0"
      ]
    ],
    "dependencies": {
      "#{cookbook_name} (2.3.4)": [

      ]
    }
  }
}
E
  end

  def minimal_lockfile
    FFI_Yajl::Parser.parse(minimal_lockfile_json)
  end

  let(:policy_name) { "chatserver" }
  let(:policy_revision_id) { "somerevisionid" }
  let(:policy_group) { "somegroup" }

  let(:chef_config) do
    double("ChefConfig").tap do |double|
      allow(double).to receive(:client_key).and_return("key")
      allow(double).to receive(:node_name).and_return("node_name")
    end
  end

  let(:minimal_lockfile_modified) do
    minimal_lockfile.tap do |lockfile|
      lockfile["cookbook_locks"]["local-cookbook"]["source_options"] = {
        "git" => repo,
        "revision" => git_revision,
        "branch" => "master",
      }
    end
  end

  let(:minimal_lockfile_modified_with_rel_path) do
    minimal_lockfile_modified.tap do |lockfile|
      lockfile["cookbook_locks"]["source_options"] = {
        "rel" => rel
      }
    end
  end

  subject(:fetcher) { described_class.new(policy_name, source_options, chef_config) }

  before do
    allow(Mixlib::ShellOut).to receive(:new).and_return(true)
  end

  context "when using revision id" do
    let(:source_options) do
      {
        server: url,
        policy_name: policy_name,
        policy_revision_id: policy_revision_id,
      }
    end

    it "calls the chef server to get the policy" do
      expect(http_client).to receive(:get).with("policies/#{policy_name}/revisions/#{policy_revision_id}").
        and_return(minimal_lockfile)
      expect(fetcher.lock_data).to eq(minimal_lockfile_modified)
    end

    context "and policy_name is not provided" do
      let(:source_options) do
        {
          server: url,
          policy_revision_id: policy_revision_id,
        }
      end

      it "calls the chef server to get the policy with the dsl name" do
        expect(http_client).to receive(:get).with("policies/#{policy_name}/revisions/#{policy_revision_id}").
          and_return(minimal_lockfile)
        expect(fetcher.lock_data).to eq(minimal_lockfile_modified)
      end
    end
  end

  context "when using policy group" do
    let(:source_options) do
      {
        server: url,
        policy_name: policy_name,
        policy_group: policy_group,
      }
    end

    let(:source_options_for_lock) do
      source_options.merge({ policy_revision_id: revision_id })
    end

    it "calls the chef server to get the policy" do
      expect(http_client).to receive(:get).with("policy_groups/#{policy_group}/policies/#{policy_name}").
        and_return(minimal_lockfile)
      expect(fetcher.lock_data).to eq(minimal_lockfile_modified)
    end

    it "includes the revision id in the source_options_for_lock" do
      allow(http_client).to receive(:get).with(
        "policy_groups/#{policy_group}/policies/#{policy_name}").and_return(minimal_lockfile)

      expect(fetcher.source_options_for_lock).to eq(source_options_for_lock)
    end

    it "correctly applies source_options that were included in the lock" do
      fetcher.apply_locked_source_options(source_options_for_lock)
      expect(http_client).to receive(:get).with(
        "policies/#{policy_name}/revisions/#{revision_id}").and_return(minimal_lockfile)
      fetcher.lock_data
    end
  end
end
