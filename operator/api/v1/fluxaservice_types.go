/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// FluxaServiceSpec defines the desired state of FluxaService
type FluxaServiceSpec struct {

	// Tier defines the service tier (tier_1, tier_2, etc.)
	// Determines ResourceQuota, LimitRange and NetworkPolicy.
	// +optional
	// +kubebuilder:default=tier_1
	Tier string `json:"tier,omitempty"`

	// Image is the main container image to deploy (e.g. "nginx:latest")
	// +required
	Image string `json:"image"`

	// Replicas is the number of pod replicas.
	// +optional
	// +kubebuilder:default=1
	// +kubebuilder:validation:Minimum=1
	Replicas int32 `json:"replicas,omitempty"`

	// Port is the container port the application listens on.
	// +optional
	// +kubebuilder:default=80
	// +kubebuilder:validation:Minimum=3000
	// +kubebuilder:validation:Maximum=65535
	Port int32 `json:"port,omitempty"`

	// Env defines environment variables for the main container.
	// Uses the standard Kubernetes EnvVar type (supports Value and ValueFrom).
	// +optional
	Env []corev1.EnvVar `json:"env,omitempty"`

	// Containers defines additional sidecar containers.
	// Uses standard Container type for maximum flexibility.
	// +optional
	Containers []corev1.Container `json:"containers,omitempty"`

	// Ingress defines how external traffic routes to this service.
	// +optional
	Ingress *IngressConfig `json:"ingress,omitempty"`
}

// IngressConfig defines how external traffic reaches the service.
type IngressConfig struct {

	// Path is the URL path prefix for routing (e.g. "/acme").
	// Used when the client does not have a custom domain.
	// +optional
	// +kubebuilder:default="/"
	Path string `json:"path,omitempty"`

	// Host is the custom domain for routing (e.g. "app.cliente.com").
	// Overrides path-based routing when set.
	// +optional
	Host string `json:"host,omitempty"`

	// ServicePort is the port the Ingress forwards requests to.
	// +optional
	// +kubebuilder:default=80
	// +kubebuilder:validation:Minimum=3000
	// +kubebuilder:validation:Maximum=65535
	ServicePort int32 `json:"servicePort,omitempty"`
}

// FluxaServiceStatus defines the observed state of FluxaService.
type FluxaServiceStatus struct {
	// Namespace is the name of the namespace created for this service.
	// +optional
	Namespace string `json:"namespace,omitempty"`

	// Conditions represent the current state of the FluxaService resource.
	// Standard condition types:
	// - "Ready": the resource is fully functional
	// - "Progressing": the resource is being created or updated
	// - "Degraded": the resource failed to reach its desired state
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// ObservedGeneration is the last generation of the spec that was reconciled.
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Namespaced,shortName=fs
// +kubebuilder:printcolumn:name="Tier",type=string,JSONPath=`.spec.tier`
// +kubebuilder:printcolumn:name="Image",type=string,JSONPath=`.spec.image`
// +kubebuilder:printcolumn:name="Replicas",type=integer,JSONPath=`.spec.replicas`
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.conditions[?(@.type=='Ready')].reason`

// FluxaService is the Schema for the fluxaservices API
type FluxaService struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitzero"`

	// spec defines the desired state of FluxaService
	// +required
	Spec FluxaServiceSpec `json:"spec"`

	// status defines the observed state of FluxaService
	// +optional
	Status FluxaServiceStatus `json:"status,omitzero"`
}

// +kubebuilder:object:root=true

// FluxaServiceList contains a list of FluxaService
type FluxaServiceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitzero"`
	Items           []FluxaService `json:"items"`
}

func init() {
	SchemeBuilder.Register(&FluxaService{}, &FluxaServiceList{})
}
