import googleapiclient.discovery
import argparse
import collections
import jinja2
import os
import hashlib
# import docker
from shutil import copyfile, copymode


zones = []
ips = {}
template_source = "haproxy.jinja2"
template_dest = "haproxy.cfg.new"
haproxy_cfg = "haproxy.cfg"
# client = docker.from_env()
# container_name = "bitcoin_haproxy"
# client = docker.APIClient(base_url='unix://var/run/docker.sock')


def get_sha512(file):
    with open(file, "rb") as f:
        bytes = f.read()
        readable_hash = hashlib.sha512(bytes).hexdigest()
        return readable_hash
    return False


# def restart_haproxy(container_name):
#     pre_container = client.containers(filters={'name': container_name})
#     if len(pre_container) > 0 and pre_container[0]['State'] is 'running':
#         client.restart(container_name)
#     else:
#         client.start(container_name)
#     post_container = client.containers(filters={'name': container_name})
#     if len(post_container) == 0 or post_container[0]['State'] is not 'running':
#         return False
#     return True


def list_instances(compute, project, zone, role):
    result = compute.instances().list(project=project, zone=zone, filter='labels.role eq ' + role).execute()
    if 'items' in result:
        return result['items']
    else:
        return False


def list_zones(compute, project):
    request = compute.zones().list(project=project).execute()
    for zone in request['items']:
        zones.append(zone['name'])
    return zones


def write_template(template_path, template_source, template_dest, template_values):
    jinja2_env = jinja2.Environment(loader=jinja2.FileSystemLoader([template_path]), trim_blocks=True)
    template = jinja2_env.get_template(template_source)
    result = template.render(hosts=template_values)
    with os.fdopen(os.open(template_dest, os.O_WRONLY | os.O_CREAT, 0o644), 'w') as handle:
        handle.write(result)
        handle.close()
    if os.path.isfile(template_dest) and os.access(template_dest, os.R_OK):
        file_stat = os.stat(template_dest)
        file_size = file_stat.st_size
        print("\tCreated  haproxy config: %s ( %s )" % (template_dest, file_size))
        return True
    return False


def main(project, role):
    compute = googleapiclient.discovery.build('compute', 'v1')
    list_zones(compute, project)
    for zone in zones:
        instances = list_instances(compute, project, zone, role)
        if instances:
            print('Retrieving ips in project %s ( %s )' % (project, zone))
            for instance in instances:
                # forced to use public ip's here...
                ips[instance['labels']['name']] = instance['networkInterfaces'][0]['accessConfigs'][0]['natIP']
                # ips[instance['labels']['name']] = instance['networkInterfaces'][0]['networkIP']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        '--project_id',
        default=os.environ['PROJECT'],
        help='Your Google Cloud project ID.'
    )
    parser.add_argument(
        '--role',
        default=os.environ['ROLE'],
        help='Your Google Cloud project ID.'
    )
    args = parser.parse_args()
    print(" - project: %s" % (args.project_id))
    print(" - role: %s" % (args.role))
    local_path = os.path.abspath(os.path.dirname(os.path.abspath(__file__)))
    # uncomment to test locally
    # local_path = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
    template_path = local_path + "/templates"
    config = local_path + "/configs/haproxy/" + haproxy_cfg
    saved_config = config + ".save"
    new_config = local_path + "/configs/haproxy/" + template_dest
    print("local_path: %s" % (local_path))
    print("template_path: %s" % (template_path))
    print("saved_config: %s" % (saved_config))
    print("new_config: %s" % (new_config))

    main(args.project_id, args.role)
    if len(ips) > 0:
        hosts = collections.OrderedDict(sorted(ips.items()))
        print(hosts)
        write_template(template_path, template_source, new_config, hosts)
    new_hash = get_sha512(local_path + "/configs/haproxy/" + template_dest)
    if new_hash is not False:
        print("new_hash: %s" % (new_hash))
    old_hash = get_sha512(local_path + "/configs/haproxy/" + haproxy_cfg)
    if old_hash is not False:
        print("old_hash: %s" % (old_hash))
    if new_hash != old_hash:
        copyfile(config, saved_config)
        copymode(config, saved_config)
        copyfile(new_config, config)
        copymode(new_config, config)
        print("haproxy configs do not match")
        print("\t - old config: %s" % (old_hash))
        print("\t - new config: %s" % (new_hash))
        # print("Restarting haproxy container")
        # if not restart_haproxy(container_name):
        #     copyfile(saved_config, config)
        #     copymode(saved_config, config)
        #     if not restart_haproxy(container_name):
        #         exit(2)
    exit(0)
